# frozen_string_literal: true

require 'rails_helper'

# ApplicationController#recover_jwt_session slides the shared session server-side: when the browser
# presents a lapsed (dropped) access cookie but a still-valid refresh cookie, the request is
# re-authenticated in place instead of being treated as logged out. See browser_sessions_spec.rb
# for the client-triggered /session/refresh counterpart.
RSpec.describe "Server-side JWT session recovery", type: :request do
  let(:user) { create(:user, :confirmed_at) }

  before { Version.default }

  # A login's refresh token, exactly as start_jwt_session mints it: an app-less user access token
  # carrying the session scopes.
  let(:anchor) do
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
  end

  def with_refresh(token) = { "Cookie" => "etm_refresh=#{token}" }

  # The root (saved_scenarios#index) is guarded by require_user, so a guest is redirected to login.
  it "recovers the session on a guarded page from a valid refresh cookie alone" do
    get "/", headers: with_refresh(anchor.refresh_token)

    expect(response).to have_http_status(:ok)
    expect(response).not_to redirect_to(new_user_session_path)
    expect(response.cookies["etm_session"]).to be_present
    expect(response.cookies["etm_session_exp"]).to be_present
  end

  it "leaves a genuine guest logged out and mints no session cookie" do
    get "/"

    expect(response).to redirect_to(new_user_session_path)
    expect(response.cookies["etm_session"]).to be_blank
  end

  it "treats a revoked refresh cookie as logged out and clears it" do
    anchor.revoke
    get "/", headers: with_refresh(anchor.refresh_token)

    expect(response).to redirect_to(new_user_session_path)
    expect(response.cookies["etm_session"]).to be_blank
    expect(response.cookies["etm_refresh"]).to be_blank
  end

  it "does not double-rotate the refresh token on /session/refresh" do
    anchor # create the sole existing token before refreshing

    expect { post "/session/refresh", headers: with_refresh(anchor.refresh_token) }
      .to change { user.access_tokens.count }.by(1)

    expect(response).to have_http_status(:no_content)
  end
end
