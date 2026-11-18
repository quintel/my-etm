# frozen_string_literal: true
require 'myetm/auth'

Doorkeeper::JWT.configure do
  # Set the payload for the JWT token. This should contain unique information
  # about the user. Defaults to a randomly generated token in a hash:
  #     { token: "RANDOM-TOKEN" }
  # opts[:scopes] is always this specific token's own granted scopes, not the application's
  # configured set, which could be broader than what was granted
  token_payload do |opts|
    MyEtm::TokenPayload.new(
      user: User.find(opts[:resource_owner_id]),
      scopes: opts[:scopes],
      application: opts[:application].presence,
      expires_in: opts[:expires_in],
      scenario_access: opts[:scenario_access]
    ).to_h
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
