# frozen_string_literal: true
require 'myetm/auth'

Doorkeeper::JWT.configure do
  # Set the payload for the JWT token. This should contain unique information
  # about the user. Defaults to a randomly generated token in a hash:
  #     { token: "RANDOM-TOKEN" }
  token_payload do |opts|
    user = User.find(opts[:resource_owner_id])

    audience = if opts[:application].present?
      # Token is valid for all audiences within this version, plus MyETM itself. MyETM is included
      # because ETEngine re-presents the caller's token to MyETM (Api::V3::BaseController#my_etm_client
      # forwards the incoming Authorization header verbatim), so a token minted here for ETEngine
      # comes back to MyETM on the same request chain and must verify there.
      #
      # This widens the audience across first-party apps and is deliberate. The proper exit is that
      # MyETM becomes the only caller of ETEngine's API and forwards on the user's behalf with its
      # own credential, rather than passing the user's token through — do not narrow the audience
      # while forwarding is in place, or these round-trip calls will start 401ing.
      opts[:application].version.urls + [Settings.auth.issuer]
    elsif opts[:scopes].to_s.split.include?("roles")
      # The shared browser-session cookie (JwtSessionCookies#start_jwt_session) carries the "roles"
      # scope and no other app-less token does: it's valid for every ETM app, across all versions,
      # since one cookie authenticates ETEngine, ETModel and Collections at once — and MyETM, whose
      # own UI and API authenticate from this same cookie (MyEtm::Auth.verify_jwt).
      Version.all.flat_map(&:urls).uniq + [Settings.auth.issuer]
    else
      # Personal Access Tokens: engine API access only. Deliberately excludes MyETM, so a leaked PAT
      # cannot be used against the endpoints that manage the user's own tokens and account. (PATs
      # still reach MyETM's API through Doorkeeper's stored-token lookup, which is a separate path
      # and is scope-checked there.)
      Version.all.map(&:engine_url)
    end

    # opts[:scopes] is always this specific token's own granted scopes (Doorkeeper passes through
    # `self.scopes` from the AccessToken being minted), whether or not it belongs to an application —
    # not the application's own configured scope set, which could be broader than what was granted.
    scopes = opts[:scopes]
    extras = opts[:expires_in].present? ? { exp: opts[:expires_in] + Time.now.to_i } : {}

    payload = {
      iss: Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil),
      iat: Time.now.to_i,
      aud: audience,
      scopes: scopes,

      # @see JWT reserved claims - https://tools.ietf.org/html/draft-jones-json-web-token-07#page-7
      jti: SecureRandom.uuid,
      sub: user.id,
      user: user.as_json(only: %i[id admin email name])
    }.merge(extras)

    # Present only on a session token minted for an opened scenario, so ETEngine can authorise from
    # the token alone.
    if opts[:scenario_grant_scenario_id].present?
      payload[ScenarioGrant::CLAIM.to_sym] = ScenarioGrant.new(
        scenario_id: opts[:scenario_grant_scenario_id],
        level: opts[:scenario_grant_level]
      ).as_claim
    end

    payload
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
