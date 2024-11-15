# frozen_string_literal: true

module MyEtm
  # Contains useful methods for authentication.
  module Auth
    DecodeError = Class.new(StandardError)
    TokenExchangeError = Class.new(StandardError)

    # Generates a new signing key for use in development and saves it to the tmp directory.
    def signing_key_content
      return ENV['OPENID_SIGNING_KEY'] if ENV['OPENID_SIGNING_KEY'].present?

      key_path = Rails.root.join('tmp/openid.key')

      return key_path.read if key_path.exist?

      unless Rails.env.test? || Rails.env.development? || ENV['DOCKER_BUILD']
        raise 'No signing key is present. Please set the OPENID_SIGNING_KEY environment ' \
              'variable or add the key to tmp/openid.key.'
      end

      key = OpenSSL::PKey::RSA.new(2048).to_pem

      unless ENV['DOCKER_BUILD']
        key_path.write(key)
        key_path.chmod(0o600)
      end

      key
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
        exp: 1.hour.from_now.to_i,
        iat: Time.now.to_i,
        scopes: scopes,
        sub: user.id,
        user: user.as_json(only: %i[id name])
      }

      key = signing_key
      JWT.encode(payload, key, 'RS256', typ: 'JWT', kid: key.to_jwk['kid'])
    end

    # Returns a Faraday client for a user, which will send requests to the specified client app.
    def client_app_client(user, client_app, scopes: [])
      client_uri = client_uri_for(client_app)

      Faraday.new(client_uri) do |conn|
        conn.request(:authorization, 'Bearer', -> { user_jwt(user, scopes:) })
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # TODO: Fixme
    # Helper method to fetch the URI for the given client application (staff application).
    def client_uri_for(client_app)
      Settings.staff_applications[client_app].uri || raise("No URI configured for client: #{client_app}")
    end

    # Decodes and verifies a JWT token or exchanges a bearer token for a JWT
    def decode(token)
      if jwt_format?(token)
        decode_jwt(token)
      else
        jwt_token = exchange_bearer_for_jwt(token)
        decode_jwt(jwt_token)
      end
    end

    # Checks if the token is in JWT format
    def jwt_format?(token)
      token.count('.') == 2
    end

    # Decodes a JWT token
    def decode_jwt(jwt_token)
      decoded_token = JWT.decode(
        jwt_token,
        signing_key.public_key,
        true,
        algorithm: 'RS256'
      ).first
      verify_claims(decoded_token)
      decoded_token.symbolize_keys
    rescue JWT::DecodeError, JWT::VerificationError, JWT::ExpiredSignature => e
      raise DecodeError, "Token verification failed: #{e.message}"
    end

    # Exchanges a bearer token for a JWT token
    def exchange_bearer_for_jwt(bearer_token)
      response = Faraday.post(Settings.identity.token_exchange_url) do |req|
        req.headers['Authorization'] = "Bearer #{bearer_token}"
        req.headers['Content-Type'] = 'application/json'
      end

      if response.success?
        JSON.parse(response.body)['jwt']
      else
        raise TokenExchangeError, 'Failed to exchange bearer token for JWT'
      end
    end

    # Verifies specific claims within the token payload
    def verify_claims(decoded_token)
      # Verify the issuer
      issuer = Doorkeeper::OpenidConnect.configuration.issuer.call(nil, nil)
      raise DecodeError, 'Invalid issuer' unless decoded_token['iss'] == issuer

      # Dynamically fetch the expected audiences from OAuth applications
      expected_audiences = Doorkeeper::Application.pluck(:uid)
      unless expected_audiences.include?(decoded_token['aud'])
        raise DecodeError, 'Invalid audience'
      end

      # Verify the token has not expired
      raise DecodeError, 'Token has expired' unless decoded_token['exp'] && decoded_token['exp'] > Time.now.to_i
    end

    module_function :decode, :jwt_format?, :decode_jwt, :exchange_bearer_for_jwt, :verify_claims, :signing_key_content, :user_jwt, :signing_key

  end
end
