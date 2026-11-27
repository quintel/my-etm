# frozen_string_literal: true

require "rails_helper"

describe StableMove::Revert, type: :service do
  let(:user) { create(:user) }
  let(:target) { create(:version, tag: "2027", hidden: true) }
  let(:log) { StableMove::Log.new(Pathname.new(Dir.mktmpdir).join("move_log.jsonl")) }

  let!(:moving) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 10) }
  let!(:alone) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 11) }
  let!(:collection) do
    create(:collection, user:, scenarios_count: 0).tap do |collection|
      create(:collection_saved_scenario, collection:, saved_scenario: moving)
    end
  end

  before do
    allow(ApiScenario::SetBound).to receive(:call!).and_return([])

    plan = JSON.parse(JSON.generate(StableMove::Plan.call(target, datasets: [ "SG_singapore" ])))
    StableMove::Commit.call(plan, export: { "planned_at" => plan["planned_at"], "missing_scenarios" => [] }, log:)
  end

  it "points every moved record back to the default version" do
    described_class.call("2027", log:)

    expect([ moving, alone, collection ].map { |record| record.reload.version }).to all(eq(Version.default))
  end

  it "logs the reverts" do
    described_class.call("2027", log:)
    expect(log.in_place("2027")).to be_empty
  end

  it "sets back the scenario ids of a saved scenario saved on the stable version" do
    moving.update!(scenario_id: 50, scenario_id_history: [ 10 ])

    expect(described_class.call("2027", log:)).to eq("reverted" => 3, "scenario_ids_restored" => [ moving.id ])
    expect(moving.reload).to have_attributes(scenario_id: 10, scenario_id_history: [])
  end

  it "refuses when a collection's own scenarios changed on the stable version" do
    create(:collection_scenario, collection:, scenario_id: 60)

    expect { described_class.call("2027", log:) }
      .to raise_error(StableMove::Error, /Collections changed on 2027: 1\n   - #{collection.id}\n/)
  end

  it "reverts only the given ids" do
    described_class.call("2027", log:, saved_scenarios: [ alone.id ])
    expect([ moving, alone ].map { |record| record.reload.version.tag }).to eq([ "2027", "latest" ])
  end

  it "refuses to split a collection from its saved scenarios" do
    expect { described_class.call("2027", log:, saved_scenarios: [ moving.id ]) }
      .to raise_error(StableMove::Error, /revert them together/)
  end

  it "summarises what it would move back, and the saved scenarios that lose their changes" do
    moving.update!(scenario_id: 50, scenario_id_history: [ 10 ])

    expect(described_class.new("2027", log:).summary).to include(
      "Moving back from 2027 to latest",
      "Records that move back: 3",
      "   - 2 saved scenarios",
      "   - 1 collection",
      "Saved scenarios that lose their changes on 2027: 1",
      "   - #{moving.id}"
    )
  end

  it "changes nothing on a summary" do
    described_class.new("2027", log:).summary
    expect(moving.reload.version).to eq(target)
  end

  it "refuses without a version" do
    expect { described_class.call(nil, log:) }.to raise_error(StableMove::Error, /give the version the records moved to/)
  end

  it "refuses a version that doesn't exist" do
    expect { described_class.call("2072", log:) }.to raise_error(StableMove::Error, /there is no version 2072/)
  end

  it "reverts nothing when it refuses" do
    expect { described_class.call("2027", log:, saved_scenarios: [ moving.id ]) }
      .to raise_error(StableMove::Error)
    expect(moving.reload.version).to eq(target)
  end
end
