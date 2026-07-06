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
  end

  before do
    routes.draw do
      get "create_session" => "anonymous#create_session"
      get "destroy_session" => "anonymous#destroy_session"
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

    it "backs the refresh cookie with a revocable Doorkeeper token (single logout)" do
      get :create_session, params: { user_id: user.id }

      token = Doorkeeper::AccessToken.by_refresh_token(response.cookies["etm_refresh"])
      expect(token.resource_owner_id).to eq(user.id)
      expect { RevokeUserSessions.call(user) }.to change { token.reload.revoked? }.to(true)
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
