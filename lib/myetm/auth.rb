# frozen_string_literal: true

module MyEtm
  # Contains useful methods for authentication.
  module Auth
    module_function

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
    def user_jwt(user, client_app, scopes: [])
      client_uri = client_uri_for(client_app)

      payload = {
        iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
        aud: client_uri,
        exp: 1.minute.from_now.to_i,
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
        conn.request(:authorization, 'Bearer', -> { user_jwt(user, client_app, scopes:) })
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # Helper method to fetch the URI for the given client application (staff application).
    def client_uri_for(client_app)
      Settings.staff_applications[client_app].uri || raise("No URI configured for client: #{client_app}")
    end
  end
end
