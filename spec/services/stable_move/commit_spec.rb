# frozen_string_literal: true

require "rails_helper"

describe StableMove::Commit, type: :service do
  let(:user) { create(:user) }
  let(:target) { create(:version, tag: "2027", hidden: true) }
  let(:log) { StableMove::Log.new(Pathname.new(Dir.mktmpdir).join("move_log.jsonl")) }
  let(:missing) { [] }
  let(:export) { { "planned_at" => plan["planned_at"], "missing_scenarios" => missing } }

  let!(:moving) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 10, scenario_id_history: [ 9 ]) }
  let!(:discarded) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 11, discarded_at: 1.day.ago) }
  let!(:collection) do
    create(:collection, user:, scenarios_count: 1).tap do |collection|
      create(:collection_saved_scenario, collection:, saved_scenario: moving)
    end
  end

  let(:plan) do
    JSON.parse(JSON.generate(StableMove::Plan.call(target, datasets: [ "SG_singapore" ])))
  end

  before do
    allow(ApiScenario::SetBound).to receive(:supported?).and_return(true)
    allow(ApiScenario::SetBound).to receive(:call!) { |_, _, ids, _| ids & missing }
  end

  it "moves the saved scenarios and collections to the stable version" do
    described_class.call(plan, export:, log:)

    expect([ moving, discarded, collection ].map { |record| record.reload.version }).to all(eq(target))
  end

  it "keeps their scenario ids" do
    described_class.call(plan, export:, log:)
    expect(moving.reload).to have_attributes(scenario_id: 10, scenario_id_history: [ 9 ])
  end

  it "binds the scenarios of kept saved scenarios and unbinds those of discarded ones" do
    described_class.call(plan, export:, log:)

    expect(ApiScenario::SetBound).to have_received(:call!).with(anything, target, [ 10, 9 ], true)
    expect(ApiScenario::SetBound).to have_received(:call!).with(anything, target, [ 11 ], false)
  end

  it "logs every record" do
    described_class.call(plan, export:, log:)

    expect(log.entries.map { |entry| entry.values_at("record_type", "record_id", "status") }).to contain_exactly(
      [ "SavedScenario", moving.id, "moved" ],
      [ "SavedScenario", discarded.id, "moved" ],
      [ "Collection", collection.id, "moved" ]
    )
  end

  context "when the stable engine lacks a current scenario the export also lacked" do
    let(:missing) { [ 11 ] }

    it "deletes that saved scenario" do
      described_class.call(plan, export:, log:)
      expect(SavedScenario.exists?(discarded.id)).to be(false)
    end
  end

  context "when the stable engine lacks a scenario the export found" do
    before { allow(ApiScenario::SetBound).to receive(:call!) { |_, _, ids, _| ids & [ 9 ] } }

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }
        .to raise_error(StableMove::Error, /lacks scenarios the export found: 9\. Export and import again/)
    end
  end

  context "when the export is of another plan" do
    let(:export) { { "planned_at" => 1.day.ago.utc.iso8601, "missing_scenarios" => [] } }

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }.to raise_error(StableMove::Error, /another plan/)
    end
  end

  context "with test data on the stable version" do
    let!(:test_data) { create(:saved_scenario, version: target) }

    it "deletes it" do
      described_class.call(plan, export:, log:)
      expect(SavedScenario.exists?(test_data.id)).to be(false)
    end
  end

  context "with a record on the stable version from before the version" do
    let!(:older) { create(:saved_scenario, version: target, created_at: target.created_at - 1.day) }

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }
        .to raise_error(StableMove::Error, /saved scenarios #{older.id} on 2027 are older than the version/)
    end

    it "deletes nothing" do
      expect { described_class.call(plan, export:, log:) }.to raise_error(StableMove::Error)
      expect(SavedScenario.exists?(older.id)).to be(true)
    end
  end

  context "when a saved scenario was saved after the plan" do
    before do
      plan
      moving.update!(scenario_id: 12, scenario_id_history: [ 9, 10 ])
    end

    it "refuses to run and lists it" do
      expect { described_class.call(plan, export:, log:) }
        .to raise_error(StableMove::Error, /Changed since the plan: saved scenarios #{moving.id}\. Plan, export/)
    end
  end

  context "when a saved scenario was created in a dataset after the plan" do
    let(:created) { create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 13) }

    before do
      plan
      created
    end

    it "refuses to run and lists it" do
      expect { described_class.call(plan, export:, log:) }
        .to raise_error(StableMove::Error, /saved scenarios #{created.id}\./)
    end
  end

  context "when a collection gained a saved scenario that stays after the plan" do
    before do
      plan
      create(:collection_saved_scenario, collection:, saved_scenario: create(:saved_scenario, user:, area_code: "nl2019"))
    end

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }.to raise_error(StableMove::Error, /move and ones that stay/)
    end
  end

  context "when the stable version is shown" do
    before { target.update!(hidden: false) }

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }.to raise_error(StableMove::Error, /is shown/)
    end
  end

  context "when the plan already ran" do
    before { described_class.call(plan, export:, log:) }

    it "refuses to run" do
      expect { described_class.call(plan, export:, log:) }.to raise_error(StableMove::Error, /Changed since the plan/)
    end

    it "runs again after a revert" do
      StableMove::Revert.call("2027", log:)
      expect(described_class.call(plan, export:, log:)).to eq("moved" => 3)
    end
  end
end
