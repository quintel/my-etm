# frozen_string_literal: true

# Unit tests for the shared-session cookie concern, exercised through an anonymous controller (the
# real login POST is bypassed by Warden test mode, so we drive the concern methods directly).
RSpec.describe JwtSessionCookies, type: :controller do
  controller(ActionController::Base) do
    include JwtSessionCookies

    def create_session
      start_jwt_session(User.find(params[:user_id]))
      head :ok
    end

    def destroy_session
      clear_jwt_session_cookies
      head :ok
    end

    def revoke_all_sessions
      revoke_all_jwt_sessions(User.find(params[:user_id]))
      head :ok
    end
  end

  before do
    routes.draw do
      get "create_session" => "anonymous#create_session"
      get "destroy_session" => "anonymous#destroy_session"
      get "revoke_all_sessions" => "anonymous#revoke_all_sessions"
    end
    Version.default
  end

  let(:user) { create(:user) }

  describe "#start_jwt_session" do
    it "sets the session, refresh and expiry cookies" do
      get :create_session, params: { user_id: user.id }

      expect(response.cookies["etm_session"]).to be_present
      expect(response.cookies["etm_refresh"]).to be_present
      expect(response.cookies["etm_session_exp"]).to be_present
    end

    it "gives the session cookie an expiry so it does not linger after the JWT expires" do
      get :create_session, params: { user_id: user.id }

      session_line = Array(response.headers["Set-Cookie"]).join("\n").split("\n")
        .find { |c| c.start_with?("etm_session=") }
      expect(session_line).to match(/expires=/i)
    end

    it "backs the refresh cookie with a revocable anchor token" do
      get :create_session, params: { user_id: user.id }

      token = Doorkeeper::AccessToken.by_refresh_token(response.cookies["etm_refresh"])
      expect(token.resource_owner_id).to eq(user.id)
      expect { token.revoke }.to change { token.reload.revoked? }.to(true)
    end
  end

  describe "cookie names" do
    it "appends the deployment's suffix" do
      allow(Settings.auth).to receive(:sso_cookie_suffix).and_return("_beta")

      expect(described_class.cookie_name("etm_session")).to eq("etm_session_beta")
    end

    # A suffix that reached only some of the cookies would be worse than none: beta would write a
    # distinct session cookie while still overwriting production's refresh or expiry cookie.
    it "applies to all three cookies, none of them named literally" do
      names = {
        described_class::SESSION_COOKIE => "etm_session",
        described_class::REFRESH_COOKIE => "etm_refresh",
        described_class::SESSION_EXP_COOKIE => "etm_session_exp"
      }

      names.each do |name, base|
        expect(name).to eq(described_class.cookie_name(base))
      end
    end
  end

  describe "#revoke_all_jwt_sessions" do
    def anchor_for(owner)
      owner.access_tokens.create!(
        expires_in: described_class::ACCESS_TTL,
        scopes: described_class::SESSION_SCOPES,
        use_refresh_token: true
      )
    end

    it "revokes the user's sessions on every device" do
      here = anchor_for(user)
      elsewhere = anchor_for(user)

      get :revoke_all_sessions, params: { user_id: user.id }

      expect(here.reload.revoked?).to be(true)
      expect(elsewhere.reload.revoked?).to be(true)
    end

    it "leaves the user's personal access tokens alone" do
      pat = CreatePersonalAccessToken.call(
        user: user, params: { name: "pipeline", permissions: :read }
      ).value!

      get :revoke_all_sessions, params: { user_id: user.id }

      expect(pat.oauth_access_token.reload.revoked?).to be(false)
    end
  end

  describe "#clear_jwt_session_cookies" do
    it "removes the session cookies" do
      get :destroy_session

      expect(response.cookies["etm_session"]).to be_blank
      expect(response.cookies["etm_refresh"]).to be_blank
      expect(response.cookies["etm_session_exp"]).to be_blank
    end
  end
end
