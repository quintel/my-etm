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
      if ENV["OPENID_SIGNING_KEY"].present?
        reformat_flat_key(ENV["OPENID_SIGNING_KEY"])
      else
        key_path = Rails.root.join("tmp/openid.key")
        if key_path.exist?
          return reformat_flat_key(key_path.read)
        end

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
    def user_jwt(user = nil, scopes: [], client_id: nil)
      payload = {
        iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
        aud: client_id,
        exp: 5.minutes.from_now.to_i,
        iat: Time.now.to_i,
        scopes: scopes,
        sub: user.id,
        user: user.as_json(only: %i[id admin])
      }

      key = signing_key
      JWT.encode(payload, key, "RS256", typ: "JWT", kid: key.to_jwk["kid"])
    end

    # TODO: Handle errors more verbosely
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
          -> { user_jwt(user, scopes: scopes, client_id: client_app.uid) }
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

    # Checks if the token is in JWT format
    def jwt_format?(token)
      token.count(".") == 2
    end

    # Decodes a JWT token
    def decode(jwt_token)
      decoded_token = JWT.decode(
        jwt_token,
        signing_key.public_key,
        true,
        algorithm: "RS256"
      ).first
      verify_claims(decoded_token)
      decoded_token.symbolize_keys
    rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature => e
      raise DecodeError, "Token verification failed: #{e.message}"
    end

    # Verifies specific claims within the token payload
    def verify_claims(decoded_token)
      # Verify the issuer
      issuer = Doorkeeper::OpenidConnect.configuration.issuer.call(nil, nil)
      raise DecodeError, "Invalid issuer" unless decoded_token["iss"] == issuer

      # Dynamically fetch the expected audiences from OAuth applications
      expected_audiences = Doorkeeper::Application.pluck(:uid)
      unless expected_audiences.include?(decoded_token["aud"])
        raise DecodeError, "Invalid audience"
      end

      # Verify the token has not expired
      raise DecodeError,
        "Token has expired" unless decoded_token["exp"] && decoded_token["exp"] > Time.now.to_i
    end

    module_function :decode, :jwt_format?, :verify_claims, :signing_key_content, :user_jwt,
      :signing_key, :model_client, :engine_client, :client_for
  end
end
