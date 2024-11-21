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
        user: user.as_json(only: %i[id admin])
      }

      key = signing_key
      JWT.encode(payload, key, 'RS256', typ: 'JWT', kid: key.to_jwk['kid'])
    end

    # Returns a Faraday client for a user, which will send requests to the specified client app.
    def client_app_client(user, client_app)
      client_app_client ||= begin
        Faraday.new(client_app.uri) do |conn|
          conn.request(:authorization, 'Bearer', -> { user_jwt(user, scopes: client_app.scopes, client_id: client_app.uid) })
          conn.request(:json)
          conn.response(:json)
          conn.response(:raise_error)
        end
      end
    end

    def engine_client(user)
      engine = OAuthApplication.find_by(uri: Settings.etengine.uri)
      client_app_client(user, engine)
    end

    def model_client(user)
      model = OAuthApplication.find_by(uri: Settings.etmodel.uri)
      client_app_client(user, model)
    end


    # Checks if the token is in JWT format
    def jwt_format?(token)
      token.count('.') == 2
    end

    # Decodes a JWT token
    def decode(jwt_token)
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

    module_function :decode, :jwt_format?, :verify_claims, :signing_key_content, :user_jwt, :signing_key, :model_client, :engine_client, :client_app_client

  end
end
