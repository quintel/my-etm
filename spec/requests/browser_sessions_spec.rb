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
    expect(response.cookies["etm_session"]).to eq(live_session)
  end

  # The morning case: every tab's keeper recovers at once with no access cookie to fall back on, so
  # all but one present a token that was rotated a moment ago. They must be handed the winner's
  # session, not signed out — a 401 here also deletes the refresh cookie the winner just wrote.
  it "adopts the winner when the refresh token was just rotated and no access cookie remains" do
    stale = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(stale)
    winner_session = response.cookies["etm_session"]

    post "/session/refresh", headers: with_refresh(stale)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["etm_session"]).to eq(winner_session)
    expect(response.cookies["etm_refresh"]).to be_present
  end

  it "signs out rather than adopting once the rotation grace has passed" do
    stale = anchor.refresh_token
    post "/session/refresh", headers: with_refresh(stale)
    Doorkeeper::AccessToken.find_by!(previous_refresh_token: stale)
      .update!(created_at: (JwtSessionCookies::ROTATION_GRACE + 1.minute).ago)

    post "/session/refresh", headers: with_refresh(stale)

    expect(response).to have_http_status(:unauthorized)
  end

  # Adoption is tied to the presented token via previous_refresh_token, not to "some recent session
  # of this user" — otherwise an unknown token rides in on a sibling tab's fresh login.
  it "signs out on an unknown refresh token even while another session is live" do
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )

    post "/session/refresh", headers: with_refresh("never-issued-token")

    expect(response).to have_http_status(:unauthorized)
  end

  # The sequential case above hits Doorkeeper's ordinary "already revoked" validation, which never
  # reaches InvalidGrantReuse. that error only comes from two requests  genuinely racing the same
  # still-live token.
  it "adopts the linked successor when Doorkeeper reports refresh-token reuse" do
    stale = anchor.refresh_token
    winner = user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
    winner.update!(previous_refresh_token: stale)
    allow(Doorkeeper::OAuth::RefreshTokenRequest).to receive(:new)
      .and_raise(Doorkeeper::Errors::InvalidGrantReuse)

    expect { post("/session/refresh", headers: with_refresh(stale)) }
      .not_to change(Doorkeeper::AccessToken, :count)

    expect(response).to have_http_status(:no_content)
    expect(response.cookies["etm_session"]).to eq(winner.token)
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

  describe "re-deriving scenario access" do
    def held_after_refresh
      post("/session/refresh", headers: with_refresh(anchor.refresh_token))
      MyEtm::Auth.verify_jwt(response.cookies["etm_session"])[ScenarioAccess::CLAIM]
    end

    let(:saved_scenario) { create(:saved_scenario, scenario_id: 10) }

    let!(:role) do
      create(
        :saved_scenario_user,
        saved_scenario:, user:, role_id: User::Roles.index_of(:scenario_collaborator)
      )
    end

    before do
      create(:saved_scenario_user, saved_scenario:, role_id: User::Roles.index_of(:scenario_owner))
      anchor.update!(scenario_access: [ [ 10, "write" ] ])
    end

    it "keeps an unchanged role's entry" do
      expect(held_after_refresh).to eq("write" => [ 10 ], "read" => [])
    end

    it "drops the entry of a collaborator removed since" do
      role.destroy!

      expect(held_after_refresh).to be_nil
    end

    it "downgrades a collaborator now a viewer" do
      role.update!(role_id: User::Roles.index_of(:scenario_viewer))

      expect(held_after_refresh).to eq("write" => [], "read" => [ 10 ])
    end

    it "drops a scenario discarded since" do
      saved_scenario.discard

      expect(held_after_refresh).to be_nil
    end
  end
end
