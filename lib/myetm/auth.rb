# frozen_string_literal: true

module MyEtm
  module Auth
    module_function

    # Reads or generates the signing key
    def signing_key_content
      return ENV['JWT_SIGNING_KEY'] if ENV['JWT_SIGNING_KEY'].present?

      key_path = Rails.root.join('tmp/jwt_signing_key.pem')

      return key_path.read if key_path.exist?

      # For development or test environments, generate a new key if it doesn't exist
      if Rails.env.development? || Rails.env.test?
        key = OpenSSL::PKey::RSA.new(2048).to_pem
        key_path.write(key)
        key_path.chmod(0o600)
        key
      else
        raise 'No signing key is present. Please set JWT_SIGNING_KEY or provide a key at tmp/jwt_signing_key.pem'
      end
    end

    # Returns the signing key as an OpenSSL::PKey::RSA instance
    def signing_key
      OpenSSL::PKey::RSA.new(signing_key_content)
    end

    # Creates a new JWT for the given user
    def user_jwt(user, scopes: [])
      payload = {
        iss: 'myetm-idp', # The issuer (MyETM)
        aud: 'client-id', # The audience (e.g., Engine or Model)
        exp: 2.hours.from_now.to_i, # Token expiration time
        iat: Time.now.to_i, # Issued at time
        sub: user.id, # The subject (user ID)
        scopes: scopes, # Optional scopes
        user: { id: user.id, name: user.name } # User details
      }

      key = signing_key
      JWT.encode(payload, key, 'RS256', typ: 'JWT', kid: key.to_jwk['kid'])
    end
  end
end
