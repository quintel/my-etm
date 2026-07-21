# frozen_string_literal: true

module MyEtm
  # Contains useful methods for authentication.
  module Auth
    module_function

    DecodeError = Class.new(StandardError)
    TokenExchangeError = Class.new(StandardError)
    SyncError = Class.new(StandardError)

    # Fetches or generates a new signing key
    def signing_key_content
      # If the key is provided via environment variable, use it
      return reformat_flat_key(ENV["OPENID_SIGNING_KEY"]) if ENV["OPENID_SIGNING_KEY"].present?

      key_path = Rails.root.join("tmp/openid.key")

      return reformat_flat_key(key_path.read) if key_path.exist?

      unless Rails.env.test? || Rails.env.development? || ENV["DOCKER_BUILD"]
        raise "No signing key is present. Please set the OPENID_SIGNING_KEY environment " \
              "variable or add the key to tmp/openid.key."
      end

      key = OpenSSL::PKey::RSA.new(2048).to_pem

      unless ENV["DOCKER_BUILD"]
        FileUtils.mkdir_p(key_path.dirname) unless key_path.dirname.exist?
        key_path.write(key)
        key_path.chmod(0o600)
      end

      key
    end

    def reformat_flat_key(raw_key)
      stripped_key = raw_key.strip

      unless stripped_key.include?("-----BEGIN RSA PRIVATE KEY-----") &&
          stripped_key.include?("-----END RSA PRIVATE KEY-----")
        raise "Invalid RSA key format"
      end

      # Extract key content
      key_content = stripped_key.gsub("-----BEGIN RSA PRIVATE KEY-----", "")
        .gsub("-----END RSA PRIVATE KEY-----", "")
        .gsub(/\s+/, "")
      formatted_body = key_content.scan(/.{1,64}/).join("\n")

      # Reassemble the key in proper PEM format
      "-----BEGIN RSA PRIVATE KEY-----\n#{formatted_body}\n-----END RSA PRIVATE KEY-----"
    end

    # Returns the signing key as an OpenSSL::PKey::RSA instance.
    def signing_key
      OpenSSL::PKey::RSA.new(signing_key_content)
    end

    # Verifies a self-issued JWT (e.g. the shared session cookie), returning the claims hash or nil.
    # Lets MyETM's own UI and API accept the session cookie via local verification — the same
    # self-contained-JWT path every other ETM app uses — instead of a Doorkeeper database lookup,
    # which only finds persisted tokens (PATs, OAuth client tokens).
    #
    # This must enforce the same claim contract as Identity::TokenDecoder, which every other app
    # uses: issuer, audience, expiry and subject. MyETM cannot use that gem (it is the provider, and
    # the gem verifies against a JWKS that MyETM itself publishes), so the two implementations are
    # kept in agreement by spec/requests/token_contract_spec.rb, which mints a real token and writes
    # the fixture the gem's own spec/identity/token_contract_spec.rb verifies against.
    #
    # Checking `aud` is what stops a token minted for another app being replayed here: MyETM hands
    # ETEngine short-lived tokens (see #client_token), and without this check any of them would
    # authenticate as that user against MyETM's own UI and API.
    def verify_jwt(token)
      payload, = JWT.decode(
        token,
        signing_key.public_key,
        true,
        algorithms: ["RS256"],
        verify_iss: true,
        iss: Settings.auth.issuer,
        verify_aud: true,
        aud: Settings.auth.issuer,
        verify_expiration: true,
        required_claims: %w[sub exp]
      )

      # required_claims only checks the key is present, not that it holds a value.
      payload["sub"].present? ? payload : nil
    rescue JWT::DecodeError
      nil
    end

    # Mints a short-lived Doorkeeper access token scoped to the given client app and returns its JWT.
    # Doorkeeper::JWT (configured in doorkeeper_jwt.rb) is the only JWT minter system-wide, so this is
    # a real, persisted (if short-lived) token rather than a second, independently-signed JWT.
    #
    # If scopes are specified (e.g. from an access token) these scopes are granted; otherwise the
    # configured app scopes are used.
    def client_token(user, client_app, scopes: [])
      scopes = scopes.empty? ? client_app.scopes : Array(scopes).join(" ")

      Doorkeeper::AccessToken.create_for(
        application: client_app, resource_owner: user, scopes: scopes,
        expires_in: 5.minutes, use_refresh_token: false
      ).token
    end

    # Returns a Faraday client for a user, which will send requests to the specified client app.
    def client_for(user, client_app, scopes: [])
      Faraday.new(client_app.uri) do |conn|
        conn.request(:authorization, "Bearer", -> { client_token(user, client_app, scopes: scopes) })
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # Returns a Faraday client for a version of ETEngine
    #
    # If scopes are specified (e.g. from an access token) these scopes are granted
    # Otherwise the configured app scopes are used
    def engine_client(user, version = Version.default, scopes: [])
      engine = OAuthApplication.find_by(uri: version.engine_url)
      client_for(user, engine, scopes: scopes)
    end

    # Returns a Faraday client for ETEngine streaming endpoints (without JSON response middleware)
    #
    # Use this for endpoints that return NDJSON (newline-delimited JSON) streams,
    # as the standard JSON response middleware will fail to parse streaming responses.
    #
    # If scopes are specified (e.g. from an access token) these scopes are granted
    # Otherwise the configured app scopes are used
    def streaming_engine_client(user, version = Version.default, scopes: [])
      engine = OAuthApplication.find_by(uri: version.engine_url)
      scopes = scopes.empty? ? engine.scopes : scopes

      Faraday.new(engine.uri) do |conn|
        conn.request(:authorization, "Bearer", -> { client_token(user, engine, scopes: scopes) })
        conn.request(:json)
        # NOTE: No response(:json) middleware - streaming responses must be parsed manually
        conn.response(:raise_error)
      end
    end

    # Returns a Faraday client for a version of ETModel
    def model_client(user, version = Version.default)
      model = OAuthApplication.find_by(uri: version.model_url)
      client_for(user, model)
    end
  end
end
