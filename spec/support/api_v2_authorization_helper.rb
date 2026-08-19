# frozen_string_literal: true

# Credential helpers for Api::V2
module AuthorizationHelper
  # A stored Doorkeeper token for the user, presented as a bearer.
  def v2_bearer(user, scopes = :delete)
    access_token_header(user, scopes)
  end

  # Revokes the token, so a spec can assert revocation takes effect immediately.
  def revoke_v2_bearer(headers)
    credential = headers["Authorization"].to_s[/\ABearer (.+)\z/, 1]

    Doorkeeper::AccessToken.by_token(credential).update!(revoked_at: Time.now.utc)
  end
end
