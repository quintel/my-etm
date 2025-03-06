# frozen_string_literal: true

module MyEtm
  # Contains useful methods for authentication.
  # TODO: go over this file!
  module Auth
    module_function

    DecodeError = Class.new(StandardError)
    TokenExchangeError = Class.new(StandardError)

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

    # Creates a new JWT for the given user, authorizing requests to the provided client.
    def user_jwt(user = nil, scopes: [], client_uri: nil)
      payload = {
        iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
        aud: client_uri,
        exp: 5.minutes.from_now.to_i,
        iat: Time.now.to_i,
        scopes: scopes,
        sub: user.id,
        user: user.as_json(only: %i[id admin email name])
      }

      key = signing_key
      JWT.encode(payload, key, "RS256", typ: "JWT", kid: key.to_jwk["kid"])
    end

    # Returns a Faraday client for a user, which will send requests to the specified client app.
    #
    # If scopes are specified (e.g. from an access token) these scopes are granted
    # Otherwise the configured app scopes are used
    def client_for(user, client_app, scopes: [])
      scopes = scopes.empty? ? client_app.scopes : scopes

      Faraday.new(client_app.uri) do |conn|
        conn.request(
          :authorization,
          "Bearer",
          -> { user_jwt(user, scopes: scopes, client_uri: client_app.uri) }
        )
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

    # Returns a Faraday client for a version of ETModel
    def model_client(user, version = Version.default)
      model = OAuthApplication.find_by(uri: version.model_url)
      client_for(user, model)
    end
  end
end
