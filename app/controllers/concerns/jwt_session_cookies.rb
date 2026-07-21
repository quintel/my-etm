# frozen_string_literal: true

# Establishes and clears the shared domain-level JWT browser session.
#
# Three cookies make up the session (all set by MyETM, the only app that holds the signing key and
# can write the parent domain):
#   - etm_session     : short-lived identity JWT (the "access cookie"), read by every subdomain app
#                       as the browser session.
#   - etm_refresh     : opaque refresh token, host-only to MyETM so the long-lived secret never
#                       reaches other subdomains. Backed by the user's *anchor token* — one
#                       app-less Doorkeeper access token representing this one browser.
#   - etm_session_exp : the access JWT's expiry (no PII, not HttpOnly) so client JS can refresh
#                       shortly before expiry without reading the HttpOnly session cookie.
#
# Single logout works by clearing the access cookie: it is set on the parent domain, so removing it
# signs the user out of ETModel, ETEngine and Collections in the same response. Revoking the anchor
# token additionally stops the session being slid again. Both are scoped to this browser — see
# #revoke_jwt_session.
module JwtSessionCookies
  extend ActiveSupport::Concern

  SESSION_COOKIE     = "etm_session"
  REFRESH_COOKIE     = "etm_refresh"
  SESSION_EXP_COOKIE = "etm_session_exp"

  # How long the access cookie is valid. Since nothing reloads the page on refresh any more, this is
  # purely a revocation-latency knob: it bounds how long a deleted account or a revoked admin role
  # keeps working.
  ACCESS_TTL = 15.minutes

  # Idle timeout, not an absolute cap: renew_jwt_session mints a new token on every refresh, so
  # created_at resets and an actively-used browser stays signed in indefinitely. Deliberate.
  REFRESH_TTL = 24.hours
  SESSION_SCOPES = "openid profile email roles scenarios:read scenarios:write scenarios:delete"

  private

  # Mints a fresh Doorkeeper access token (app-less: it belongs to the user directly, not an
  # OAuthApplication) plus a Doorkeeper-generated refresh token, then writes the cookies. The token's
  # own `.token` value IS the access JWT — Doorkeeper::JWT (configured in doorkeeper_jwt.rb) is the
  # only JWT minter system-wide, so there's no second, separately-signed JWT to keep in sync with it.
  def start_jwt_session(user)
    access = user.access_tokens.create!(
      expires_in: ACCESS_TTL, scopes: SESSION_SCOPES, use_refresh_token: true
    )
    write_session_cookies(access)
  end

  # Refreshes the session from the refresh cookie via Doorkeeper's own refresh grant (the same
  # atomic validate/mint-new logic behind grant_type=refresh_token at the token endpoint). `nil`
  # credentials is correct here: the anchor token has no `application`, so Doorkeeper's client checks
  # are skipped (see RefreshTokenRequest#validate_*).
  #
  # Returns false if the token is missing, revoked, or has been idle past the sliding window — i.e.
  # the caller should clear the cookies and return 401.
  def renew_jwt_session
    old = Doorkeeper::AccessToken.by_refresh_token(cookies[REFRESH_COOKIE])
    return false unless old && refresh_token_live?(old)

    response = Doorkeeper::OAuth::RefreshTokenRequest.new(Doorkeeper.config, old, nil, {}).authorize
    return false unless response.is_a?(Doorkeeper::OAuth::TokenResponse)

    old.revoke unless old.revoked?
    write_session_cookies(response.token)
    true
  rescue Doorkeeper::Errors::InvalidGrantReuse
    # The refresh token was revoked concurrently
    false
  end

  def write_session_cookies(access)
    # Max-Age matches each cookie's lifetime so an expired session cookie is dropped rather than
    # lingering: the access cookie dies with its JWT, the refresh cookie spans the sliding window.
    cookies[SESSION_COOKIE] =
      parent_cookie_options.merge(value: access.token, httponly: true, expires: ACCESS_TTL)
    cookies[REFRESH_COOKIE] =
      refresh_cookie_options.merge(value: access.refresh_token, httponly: true, expires: REFRESH_TTL)
    cookies[SESSION_EXP_COOKIE] =
      parent_cookie_options.merge(value: ACCESS_TTL.from_now.to_i.to_s, expires: ACCESS_TTL)
  end

  # Revokes the anchor token behind this browser's refresh cookie, so the session cannot be slid
  # again after logout.
  #
  # Deliberately browser-scoped. The user's personal access tokens live in the same
  # `user.access_tokens` association as the anchor token, so revoking by user — as this used to —
  # destroyed every PAT the user owned the moment they signed out of the web UI, breaking their
  # scripted API clients with no warning. Resolving the token from the refresh cookie makes PATs
  # (and sessions on the user's other devices) untouchable by construction rather than by an
  # exclusion clause someone can regress.
  #
  # "Sign out everywhere" and account deletion are separate, explicit actions and belong elsewhere.
  def revoke_jwt_session
    anchor = Doorkeeper::AccessToken.by_refresh_token(cookies[REFRESH_COOKIE])
    anchor.revoke if anchor && !anchor.revoked?
  end

  def clear_jwt_session_cookies
    cookies.delete(SESSION_COOKIE, **parent_cookie_options.slice(:domain))
    cookies.delete(SESSION_EXP_COOKIE, **parent_cookie_options.slice(:domain))
    cookies.delete(REFRESH_COOKIE)
  end

  def refresh_token_live?(token)
    token.created_at + REFRESH_TTL > Time.current
  end

  # Parent-domain cookie options, so every sibling subdomain reads it. Secure only under TLS so the
  # HTTP dev stack works.
  def parent_cookie_options
    options = { secure: request.ssl?, same_site: :lax }
    domain = Settings.auth.sso_cookie_domain.to_s.delete_prefix(".")
    options[:domain] = ".#{domain}" if domain.present? && request.host.end_with?(domain)
    options
  end

  # Refresh cookie is host-only to MyETM (no Domain), keeping the long-lived secret off every other
  # subdomain. A credentialed cross-subdomain fetch to MyETM's refresh endpoint still sends it.
  def refresh_cookie_options
    { secure: request.ssl?, same_site: :lax }
  end
end
