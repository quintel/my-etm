# frozen_string_literal: true

RSpec.describe "Shared JWT browser session refresh", type: :request do
  let(:user) { create(:user, :confirmed_at) }

  before { Version.default }

  # A login's refresh token, as the browser presents it back to MyETM. Mirrors what start_jwt_session
  # writes: an app-less user access token carrying the session scopes (the "roles" scope is what
  # marks this as a session token, not a Personal Access Token, to Doorkeeper::JWT's audience logic).
  let(:anchor) do
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
  end

  def with_refresh(token) = { "Cookie" => "etm_refresh=#{token}" }

  it "re-mints the session and expiry cookies from a valid refresh cookie" do
    post "/session/refresh", headers: with_refresh(anchor.refresh_token)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["etm_session"]).to be_present
    expect(response.cookies["etm_session_exp"]).to be_present
  end

  it "mints an access JWT carrying every in-scope app URL as audience" do
    post "/session/refresh", headers: with_refresh(anchor.refresh_token)

    payload, = JWT.decode(
      response.cookies["etm_session"], MyEtm::Auth.signing_key.public_key, true, algorithm: "RS256"
    )
    expect(payload["aud"]).to match_array(Version.all.flat_map(&:urls).uniq)
    expect(payload["sub"]).to eq(user.id)
  end

  it "rotates the refresh token, revoking the old one (sliding window)" do
    old = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(old)

    expect(anchor.reload.revoked?).to be(true)
    expect(response.cookies["etm_refresh"]).to be_present
    expect(response.cookies["etm_refresh"]).not_to eq(old)
  end

  it "returns 401 when no refresh cookie is present" do
    post "/session/refresh"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for a revoked refresh token (e.g. after RevokeUserSessions on logout)" do
    anchor.revoke
    post "/session/refresh", headers: with_refresh(anchor.refresh_token)

    expect(response).to have_http_status(:unauthorized)
  end
end
