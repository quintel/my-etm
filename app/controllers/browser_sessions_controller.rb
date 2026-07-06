# frozen_string_literal: true

# Refreshes the shared JWT browser session. Apps call this (a credentialed cross-subdomain fetch)
# shortly before the access JWT expires, or after a 401, to slide the session without re-login.
class BrowserSessionsController < ApplicationController
  include JwtSessionCookies

  # The refresh cookie is the credential and is SameSite=Lax (so a cross-site POST can't carry it);
  # the request comes from sibling subdomains via fetch, which won't send a Rails CSRF token.
  skip_before_action :verify_authenticity_token, only: :refresh

  def refresh
    if renew_jwt_session
      head :no_content
    else
      clear_jwt_session_cookies
      head :unauthorized
    end
  end
end
