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

  # MyETM's own URL is in the audience because its UI and API authenticate from this same cookie.
  it "mints an access JWT carrying every in-scope app URL, and MyETM, as audience" do
    post "/session/refresh", headers: with_refresh(anchor.refresh_token)

    payload, = JWT.decode(
      response.cookies["etm_session"], MyEtm::Auth.signing_key.public_key, true, algorithm: "RS256"
    )
    expect(payload["aud"])
      .to match_array(Version.all.flat_map(&:urls).uniq + [Settings.auth.issuer])
    expect(payload["sub"]).to eq(user.id)
  end

  it "rotates the refresh token, revoking the old one (sliding window)" do
    old = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(old)

    expect(anchor.reload.revoked?).to be(true)
    expect(response.cookies["etm_refresh"]).to be_present
    expect(response.cookies["etm_refresh"]).not_to eq(old)
  end

  # Several tabs slide the session at roughly the same moment. Whichever request arrives second was
  # already in flight when the first rotated the token, so it presents a refresh token that has just
  # been revoked — but the browser is plainly still signed in, and must stay that way.
  it "keeps the session when the refresh token is stale but the access cookie is still live" do
    stale = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(stale)
    live_session = response.cookies["etm_session"]

    post "/session/refresh", headers: { "Cookie" => "etm_refresh=#{stale}; etm_session=#{live_session}" }

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["etm_session"]).to be_blank
  end

  it "returns 401 when the refresh token is stale and the access cookie has gone too" do
    stale = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(stale)
    post "/session/refresh", headers: with_refresh(stale)

    expect(response).to have_http_status(:unauthorized)
  end

  # The sequential case above hits Doorkeeper's ordinary "already revoked" validation, which never
  # reaches InvalidGrantReuse. that error only comes from two requests  genuinely racing the same
  # still-live token.
  it "adopts a concurrently-minted token instead of signing the browser out on a rotation race" do
    stale = anchor.refresh_token
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
    allow(Doorkeeper::OAuth::RefreshTokenRequest).to receive(:new)
      .and_raise(Doorkeeper::Errors::InvalidGrantReuse)

    expect { post("/session/refresh", headers: with_refresh(stale)) }
      .not_to change(Doorkeeper::AccessToken, :count)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["etm_session"]).to be_present
  end

  it "still signs out when reuse is detected but no concurrent winner can be found" do
    stale = anchor.refresh_token
    anchor.revoke
    allow(Doorkeeper::OAuth::RefreshTokenRequest).to receive(:new)
      .and_raise(Doorkeeper::Errors::InvalidGrantReuse)

    post "/session/refresh", headers: with_refresh(stale)

    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 when no refresh cookie is present" do
    post "/session/refresh"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns 401 for a revoked refresh token (e.g. after the anchor token is revoked on logout)" do
    anchor.revoke
    post "/session/refresh", headers: with_refresh(anchor.refresh_token)

    expect(response).to have_http_status(:unauthorized)
  end
end
