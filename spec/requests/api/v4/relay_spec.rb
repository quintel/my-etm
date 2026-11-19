# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V4::Relay", type: :request, api: true do
  let(:owner) { create(:user) }
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: owner, scenario_id: 648_695, private: true) }
  let(:engine_url) { saved_scenario.version.engine_url }

  def pat_for(caller, permissions: :write)
    CreatePersonalAccessToken.call(user: caller, params: { name: "pyetm", permissions: })
      .value!.oauth_access_token
  end

  def bearer(token)
    { "Authorization" => "Bearer #{token.token}" }
  end

  def give_role(role)
    create(:saved_scenario_user, saved_scenario:, user:, role_id: User::Roles.index_of(role))
  end

  def ask(path, method: "GET", headers: {}, id: saved_scenario.id)
    get "/api/v4/relay/verdict", headers: headers.merge(
      "X-Original-URI" => "/api/v4/saved_scenarios/#{id}/#{path}", "X-Original-Method" => method
    )
  end

  def relay_claims
    JWT.decode(
      response.headers["X-Relay-Token"], MyEtm::Auth.signing_key.public_key, true, algorithms: [ "RS256" ]
    ).first
  end

  def grant
    relay_claims.dig("scenario_access", saved_scenario.version.tag)
  end

  describe "an allowed call" do
    let(:pat) { pat_for(user) }

    before { give_role(:scenario_collaborator) }

    it "answers without a body" do
      ask("inputs", headers: bearer(pat))

      expect(response).to have_http_status(:no_content)
    end

    it "names the engine of the Scenario's Version" do
      ask("inputs", headers: bearer(pat))

      expect(response.headers["X-Engine-Origin"]).to eq(engine_url)
    end

    it "addresses the current Session on the engine, without the query" do
      get "/api/v4/relay/verdict", headers: bearer(pat).merge(
        "X-Original-URI" => "/api/v4/saved_scenarios/#{saved_scenario.id}/curves/merit_order.csv?x=1",
        "X-Original-Method" => "GET"
      )

      expect(response.headers["X-Engine-Path"]).to eq("/api/v3/scenarios/648695/curves/merit_order.csv")
    end

    it "gives the access log its user, token and Version" do
      ask("inputs", headers: bearer(pat))

      expect(response.headers.values_at("X-Etm-User-Id", "X-Etm-Token-Id", "X-Etm-Version"))
        .to eq([ user.id.to_s, pat.id.to_s, "latest" ])
    end

    it "relays the Session itself, which is how inputs are set" do
      ask("", method: "PUT", headers: bearer(pat))

      expect(response.headers["X-Engine-Path"]).to eq("/api/v3/scenarios/648695/")
    end

    it "resolves a 2025.01 Scenario to the stable engine" do
      saved_scenario.update!(version: create(:version, tag: "2025.01", url_prefix: "stable."))
      ask("inputs", headers: bearer(pat))

      expect(response.headers["X-Engine-Origin"]).to eq("https://stable.engine.energytransitionmodel.com")
    end

    it "records the PAT's use at most once every two minutes" do
      headers = bearer(pat)
      personal = PersonalAccessToken.find_by(oauth_access_token: pat)

      personal.update!(last_used_at: 1.minute.ago)
      expect { ask("inputs", headers:) }.not_to(change { personal.reload.last_used_at })

      personal.update!(last_used_at: 3.minutes.ago)
      expect { ask("inputs", headers:) }.to(change { personal.reload.last_used_at })
    end

    it "writes no access token row" do
      headers = bearer(pat)

      expect { ask("inputs", headers:) }.not_to change(Doorkeeper::AccessToken, :count)
    end
  end

  describe "the relay token" do
    it "gives an owner write" do
      ask("inputs", headers: bearer(pat_for(owner)))

      expect(grant).to eq("write" => [ 648_695 ])
    end

    it "gives a collaborator write" do
      give_role(:scenario_collaborator)
      ask("inputs", headers: bearer(pat_for(user)))

      expect(grant).to eq("write" => [ 648_695 ])
    end

    it "gives a viewer read" do
      give_role(:scenario_viewer)
      ask("inputs", headers: bearer(pat_for(user)))

      expect(grant).to eq("read" => [ 648_695 ])
    end

    it "gives read on a public Scenario the caller holds no role on" do
      saved_scenario.update!(private: false)
      ask("inputs", headers: bearer(pat_for(user)))

      expect(grant).to eq("read" => [ 648_695 ])
    end

    it "carries only a read scoped PAT's own scopes, so the engine refuses its writes" do
      ask("inputs", headers: bearer(pat_for(owner, permissions: :read)))

      expect(relay_claims["scopes"].split).to contain_exactly("openid", "public", "scenarios:read")
    end

    it "never carries roles or scenarios:bind, even from a token that holds them" do
      token = Doorkeeper::AccessToken.create!(
        resource_owner_id: owner.id, scopes: "openid roles scenarios:read scenarios:bind", expires_in: 1.hour
      )
      ask("inputs", headers: bearer(token))

      expect(relay_claims["scopes"].split).to contain_exactly("openid", "scenarios:read")
    end

    it "names only the Scenario's Version's engine" do
      ask("inputs", headers: bearer(pat_for(owner)))

      expect(relay_claims["aud"]).to eq([ engine_url ])
    end

    it "expires within two minutes" do
      ask("inputs", headers: bearer(pat_for(owner)))

      expect(relay_claims["exp"]).to be <= 2.minutes.from_now.to_i
    end

    it "identifies its user as the engine's User.from_jwt! needs" do
      ask("inputs", headers: bearer(pat_for(owner)))

      expect(relay_claims).to include(
        "sub" => owner.id, "user" => include("id" => owner.id, "email" => owner.email, "name" => owner.name)
      )
    end

    it "names its key with the published kid and has no PAT prefix" do
      ask("inputs", headers: bearer(pat_for(owner)))
      token = response.headers["X-Relay-Token"]

      expect(JWT.decode(token, nil, false).last["kid"]).to eq(Doorkeeper::OpenidConnect.signing_key.kid)
      expect(PersonalAccessToken.prefixed?(token)).to be(false)
    end
  end

  describe "an anonymous caller" do
    it "is relayed with no token to a public Scenario" do
      saved_scenario.update!(private: false)
      ask("inputs")

      expect(response).to have_http_status(:no_content)
      expect(response.headers).to include("X-Engine-Origin")
      expect(response.headers).not_to include("X-Relay-Token", "X-Etm-User-Id")
    end

    it "is told to authenticate for a private Scenario" do
      ask("inputs")

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "a refused call" do
    let(:pat) { pat_for(user) }

    def render_refusal
      refusal = Api::V4::RelayController::REFUSAL_HEADERS.to_h { |name| [ name, response.headers[name] ] }
      get "/api/v4/relay/refusal", headers: refusal.compact
    end

    shared_examples "a refusal" do |verdict:, status:, code:|
      it "answers the verdict #{verdict}, with no engine origin" do
        refuse

        expect(response).to have_http_status(verdict)
        expect(response.headers).not_to include("X-Engine-Origin", "X-Relay-Token")
      end

      it "renders #{code} with #{status}" do
        refuse
        render_refusal

        expect(response).to have_http_status(status)
        expect(response.parsed_body).to validate_against_the_v4_envelope(:error)
        expect(response.parsed_body.dig("errors", 0, "code")).to eq(code)
      end
    end

    context "when the Scenario does not exist" do
      def refuse = ask("inputs", headers: bearer(pat), id: 0)

      it_behaves_like "a refusal", verdict: :forbidden, status: :not_found, code: "scenario_not_found"
    end

    context "when the Scenario is discarded" do
      before do
        give_role(:scenario_owner)
        saved_scenario.discard
      end

      def refuse = ask("inputs", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :conflict, code: "scenario_discarded"
    end

    context "when the caller cannot read the Scenario" do
      def refuse = ask("inputs", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :not_found, code: "not_found"
    end

    context "when an anonymous caller asks for a private Scenario" do
      def refuse = ask("inputs")

      it_behaves_like "a refusal", verdict: :unauthorized, status: :unauthorized, code: "unauthenticated"
    end

    context "when the PAT is revoked" do
      before do
        give_role(:scenario_owner)
        pat.revoke
      end

      def refuse = ask("inputs", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :unauthorized, status: :unauthorized, code: "unauthenticated"
    end

    context "when the caller's role was removed" do
      before do
        give_role(:scenario_viewer)
        ask("inputs", headers: bearer(pat))
        SavedScenarioUser.where(user:).destroy_all
      end

      def refuse = ask("inputs", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :not_found, code: "not_found"
    end

    {
      "users" => "users",
      "users with a format suffix" => "users.json",
      "dump" => "dump",
      "interpolate" => "interpolate",
      "a .. segment" => "inputs/../users",
      "an encoded .. segment" => "%2e%2e/scenarios",
      "an empty segment hiding users" => "/users"
    }.each do |name, path|
      context "with #{name}" do
        let(:denied_path) { path }

        before { give_role(:scenario_owner) }

        def refuse = ask(denied_path, headers: bearer(pat))

        it_behaves_like "a refusal", verdict: :forbidden, status: :forbidden, code: "forbidden"
      end
    end

    context "with a DELETE of the Session itself" do
      before { give_role(:scenario_owner) }

      def refuse = ask("", method: "DELETE", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :forbidden, code: "forbidden"
    end

    context "with a POST to the Session itself, which the engine may override into a DELETE" do
      before { give_role(:scenario_owner) }

      def refuse = ask("", method: "POST", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :forbidden, code: "forbidden"
    end

    context "without the original call" do
      def refuse = get("/api/v4/relay/verdict", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :forbidden, code: "forbidden"
    end

    context "without the original method" do
      before { give_role(:scenario_owner) }

      def refuse = ask("", method: "", headers: bearer(pat))

      it_behaves_like "a refusal", verdict: :forbidden, status: :forbidden, code: "forbidden"
    end

    it "renders forbidden when no refusal is handed over" do
      get "/api/v4/relay/refusal"

      expect(response).to have_http_status(:forbidden)
    end
  end
end
