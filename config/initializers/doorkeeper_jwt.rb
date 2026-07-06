# frozen_string_literal: true
require 'myetm/auth'

Doorkeeper::JWT.configure do
  # Set the payload for the JWT token. This should contain unique information
  # about the user. Defaults to a randomly generated token in a hash:
  #     { token: "RANDOM-TOKEN" }
  token_payload do |opts|
    user = User.find(opts[:resource_owner_id])

    audience = if opts[:application].present?
      # Token is valid for all audiences within this version
      opts[:application].version.urls
    elsif opts[:scopes].to_s.split.include?("roles")
      # The shared browser-session cookie (JwtSessionCookies#start_jwt_session) carries the "roles"
      # scope and no other app-less token does: it's valid for every ETM app, across all versions,
      # since one cookie authenticates ETEngine, ETModel and Collections at once.
      Version.all.flat_map(&:urls).uniq
    else
      # Personal Access Tokens: engine API access only.
      Version.all.map(&:engine_url)
    end

    # opts[:scopes] is always this specific token's own granted scopes (Doorkeeper passes through
    # `self.scopes` from the AccessToken being minted), whether or not it belongs to an application —
    # not the application's own configured scope set, which could be broader than what was granted.
    scopes = opts[:scopes]
    extras = opts[:expires_in].present? ? { exp: opts[:expires_in] + Time.now.to_i } : {}

    {
      iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
      iat: Time.now.to_i,
      aud: audience,
      scopes: scopes,

      # @see JWT reserved claims - https://tools.ietf.org/html/draft-jones-json-web-token-07#page-7
      jti: SecureRandom.uuid,
      sub: user.id,
      user: user.as_json(only: %i[id admin email name])
    }.merge(extras)
  end

  # Optionally set additional headers for the JWT. See
  # https://tools.ietf.org/html/rfc7515#section-4.1
  # Reuses Doorkeeper::OpenidConnect's own kid for this key, rather than independently deriving one:
  # that's the kid /oauth/discovery/keys actually publishes, and every consumer verifies tokens by
  # looking up this exact kid there.
  token_headers do |_opts|
    { kid: Doorkeeper::OpenidConnect.signing_key.kid }
  end

  # Must stay false: every ETM app verifies tokens against the one shared signing key (via kid, see
  # token_headers above), including the shared browser-session cookie which isn't tied to a single
  # OAuthApplication at all. Per-application secrets would break that shared verification model.
  use_application_secret false

  # Set the signing secret. This would be shared with any other applications
  # that should be able to verify the authenticity of the token. Defaults to "secret".
  secret_key MyEtm::Auth.signing_key_content

  # If you want to use RS* algorithms specify the path to the RSA key to use for
  # signing. If you specify a `secret_key_path` it will be used instead of
  # `secret_key`.
  # secret_key_path Rails.root.join('tmp/openid.key')

  # Specify cryptographic signing algorithm type (https://github.com/progrium/ruby-jwt). Defaults to
  # `nil`.
  signing_method 'RS256'
end
