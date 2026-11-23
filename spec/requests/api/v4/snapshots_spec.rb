# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V4::Snapshots", type: :request, api: true do
  let(:owner) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: owner, scenario_id: 100) }
  let(:path) { "/api/v4/saved_scenarios/#{saved_scenario.id}/snapshots" }
  let(:engine) { instance_double(Faraday::Connection, put: nil, post: nil) }

  before do
    allow(MyEtm::Auth).to receive(:engine_client).and_return(engine)
    allow(ApiScenario::SetBound).to receive(:call).and_return(Dry::Monads::Success([]))
    allow(ApiScenario::Create).to receive(:call).and_return(Dry::Monads::Success("id" => 200))
  end

  def save_snapshot(user = owner, scopes = :write)
    post(path, headers: v4_bearer(user, scopes), as: :json)
  end

  def give_role(role)
    create(:saved_scenario_user, saved_scenario:, user: create(:user), role_id: User::Roles.index_of(role)).user
  end

  it "makes a clone of the current Session current, and keeps the old one as a Snapshot" do
    save_snapshot

    expect(response).to have_http_status(:created)
    expect(response.parsed_body).to validate_against_the_v4_envelope(:resource)
    expect(ApiScenario::Create).to have_received(:call).with(engine, { scenario_id: 100 })
    expect(saved_scenario.reload).to have_attributes(scenario_id: 200, scenario_id_history: [ 100 ])
  end

  it "relays the next call to the new current Session" do
    save_snapshot

    get "/api/v4/relay/verdict", headers: v4_bearer(owner, :write).merge(
      "X-Original-URI" => "/api/v4/saved_scenarios/#{saved_scenario.id}/inputs", "X-Original-Method" => "PUT"
    )

    expect(response.headers["X-Engine-Path"]).to eq("/api/v3/scenarios/200/inputs")
  end

  it "lets a collaborator save" do
    save_snapshot(give_role(:scenario_collaborator))

    expect(response).to have_http_status(:created)
  end

  it "refuses a viewer" do
    save_snapshot(give_role(:scenario_viewer))

    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a read scoped token" do
    save_snapshot(owner, :read)

    expect(response).to have_http_status(:forbidden)
  end

  it "refuses a discarded scenario" do
    saved_scenario.discard
    save_snapshot

    expect(response).to have_http_status(:conflict)
  end

  it "answers 502 and changes nothing when the clone fails" do
    allow(ApiScenario::Create).to receive(:call)
      .and_return(Dry::Monads::Failure([ :upstream, [ "Failed to create the session in ETEngine" ] ]))

    save_snapshot

    expect(response.parsed_body.dig("errors", 0, "code")).to eq("upstream_error")
    expect(saved_scenario.reload).to have_attributes(scenario_id: 100, scenario_id_history: [])
  end
end
