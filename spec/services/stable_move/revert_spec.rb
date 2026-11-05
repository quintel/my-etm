# frozen_string_literal: true

require "rails_helper"

describe StableMove::Revert, type: :service do
  let(:user) { create(:user) }
  let(:target) { create(:version, tag: "2027.01", hidden: true) }
  let(:log) { StableMove::Log.new(Pathname.new(Dir.mktmpdir).join("move_log.jsonl")) }

  let!(:moving) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 10) }
  let!(:alone) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 11) }
  let!(:collection) do
    create(:collection, user:, scenarios_count: 0).tap do |collection|
      create(:collection_saved_scenario, collection:, saved_scenario: moving)
    end
  end

  before do
    allow(ApiScenario::SetBound).to receive_messages(supported?: true, call!: [])

    plan = JSON.parse(JSON.generate(StableMove::Plan.call(target, datasets: [ "SG_singapore" ])))
    StableMove::Commit.call(plan, log:)
  end

  it "points every moved record back to the default version" do
    described_class.call("2027.01", log:)

    expect([ moving, alone, collection ].map { |record| record.reload.version }).to all(eq(Version.default))
  end

  it "logs the reverts" do
    described_class.call("2027.01", log:)
    expect(log.in_place("2027.01")).to be_empty
  end

  it "reverts only the given ids" do
    described_class.call("2027.01", log:, saved_scenarios: [ alone.id ])
    expect([ moving, alone ].map { |record| record.reload.version.tag }).to eq([ "2027.01", "latest" ])
  end

  it "refuses to split a collection from its saved scenarios" do
    expect { described_class.call("2027.01", log:, saved_scenarios: [ moving.id ]) }
      .to raise_error(StableMove::Error, /Revert them together/)
  end

  it "reverts nothing when it refuses" do
    expect { described_class.call("2027.01", log:, saved_scenarios: [ moving.id ]) }
      .to raise_error(StableMove::Error)
    expect(moving.reload.version).to eq(target)
  end
end
