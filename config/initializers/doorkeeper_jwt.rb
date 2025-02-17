# frozen_string_literal: true
require 'myetm/auth'

Doorkeeper::JWT.configure do
  # Set the payload for the JWT token. This should contain unique information
  # about the user. Defaults to a randomly generated token in a hash:
  #     { token: "RANDOM-TOKEN" }
  token_payload do |opts|
    user = User.find(opts[:resource_owner_id])
    audience = if opts[:application].present?
      opts[:application][:uri]
    else
      Version.all.map(&:engine_url)
    end

    scopes = opts[:application].present? ? opts[:application][:scopes] : opts[:scopes]

    {
      iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
      iat: Time.now.to_i,
      aud: audience,

      # Matches access_token default from doorkeeper init
      exp: 2.hours.from_now.to_i,
      scopes: scopes,

      # @see JWT reserved claims - https://tools.ietf.org/html/draft-jones-json-web-token-07#page-7
      jti: SecureRandom.uuid,
      sub: user.id,
      user: user.as_json(only: %i[id admin email])
    }
  end

  # Optionally set additional headers for the JWT. See
  # https://tools.ietf.org/html/rfc7515#section-4.1
  # JWK can be used to automatically verify RS* tokens client-side if token's kid matches a public kid in /oauth/discovery/keys
  token_headers do |_opts|
    key = OpenSSL::PKey::RSA.new(MyEtm::Auth.signing_key_content)
    { kid: JWT::JWK.new(key)[:kid] }
  end

  # TODO: check if we need this now that we use the above KIDs!
  # Use the application secret specified in the access grant token. Defaults to
  # `false`. If you specify `use_application_secret true`, both `secret_key` and
  # `secret_key_path` will be ignored.
  use_application_secret false

  # Set the signing secret. This would be shared with any other applications
  # that should be able to verify the authenticity of the token. Defaults to "secret".
  # TODO-NS: recheck if it shoudl be ENV['OPENID_SIGNING_KEY']
  secret_key MyEtm::Auth.signing_key_content

  # If you want to use RS* algorithms specify the path to the RSA key to use for
  # signing. If you specify a `secret_key_path` it will be used instead of
  # `secret_key`.
  # TODO-NS: recheck
  # secret_key_path Rails.root.join('tmp/openid.key')

  # Specify cryptographic signing algorithm type (https://github.com/progrium/ruby-jwt). Defaults to
  # `nil`.
  signing_method 'RS256'
end