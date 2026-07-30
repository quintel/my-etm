# frozen_string_literal: true

# Credential helpers for the two Api::V2 authentication lanes.
module AuthorizationHelper
  # Returns a Cookie header
  def v2_session_cookie(user, scopes: JwtSessionCookies::SESSION_SCOPES)
    token = user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: scopes, use_refresh_token: true
    )

    { 'Cookie' => "#{JwtSessionCookies::SESSION_COOKIE}=#{token.token}" }
  end

  # A personal access token: a stored Doorkeeper token with no application, which is what
  # makes it a PAT rather than a client token.
  def v2_pat_header(user, scopes = :read)
    access_token_header(user, scopes)
  end

  # Revokes the PAT, so a spec can assert revocation takes effect immediately
  # rather than at expiry.
  def revoke_v2_pat(headers)
    credential = headers['Authorization'].to_s[/\ABearer (.+)\z/, 1]

    Doorkeeper::AccessToken.by_token(credential).update!(revoked_at: Time.now.utc)
  end
end
