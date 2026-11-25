# frozen_string_literal: true

require "rails_helper"

RSpec.describe SavedScenarioCallbacksJob, type: :job do
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user:, scenario_id: 100) }
  let(:http_client) { instance_double(Faraday::Connection) }

  before do
    allow(MyEtm::Auth).to receive(:engine_client).and_return(http_client)
    allow(SavedScenario::PerformEngineCallbacks).to receive(:call).and_return(Dry::Monads::Success(1))
  end

  it "grants the engine client on the saved scenario" do
    described_class.perform_now(100, user.id, saved_scenario.version.tag, saved_scenario_id: saved_scenario.id)

    expect(MyEtm::Auth).to have_received(:engine_client)
      .with(user, saved_scenario.version, scenario: saved_scenario)
  end

  it "grants nothing without a saved scenario" do
    described_class.perform_now(100, user.id, saved_scenario.version.tag)

    expect(MyEtm::Auth).to have_received(:engine_client)
      .with(user, saved_scenario.version, scenario: nil)
  end

  it "protects and tags by default" do
    described_class.perform_now(100, user.id, saved_scenario.version.tag, saved_scenario_id: saved_scenario.id)

    expect(SavedScenario::PerformEngineCallbacks).to have_received(:call)
      .with(http_client, 100, operations: [ :protect, :tag_version ], saved_scenario:)
  end

  it "passes the given operations as symbols" do
    described_class.perform_now(100, user.id, saved_scenario.version.tag, [ "set_privacy" ],
      saved_scenario_id: saved_scenario.id)

    expect(SavedScenario::PerformEngineCallbacks).to have_received(:call)
      .with(http_client, 100, operations: [ :set_privacy ], saved_scenario:)
  end
end
