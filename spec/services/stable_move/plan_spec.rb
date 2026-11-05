# frozen_string_literal: true

require "rails_helper"

describe StableMove::Plan, type: :service do
  let(:user) { create(:user) }
  let(:target) { create(:version, tag: "2027", hidden: true) }

  let!(:moving) do
    create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 10, scenario_id_history: [ 8, 9 ])
  end

  let!(:discarded) do
    create(:saved_scenario, user:, area_code: "SG_singapore", scenario_id: 11, discarded_at: 1.day.ago)
  end

  let!(:staying) { create(:saved_scenario, user:, area_code: "nl2019", scenario_id: 20) }
  let!(:picked) { create(:saved_scenario, user:, area_code: "de", scenario_id: 30) }

  let(:plan) { described_class.call(target, datasets: [ "SG_singapore" ], handpicked: [ picked.id, 999_999 ]) }

  def collection_with(*saved_scenarios, **attributes)
    create(:collection, user:, scenarios_count: 0, **attributes).tap do |collection|
      saved_scenarios.each { |saved| create(:collection_saved_scenario, collection:, saved_scenario: saved) }
    end
  end

  before { create(:saved_scenario, area_code: "SG_singapore", version: Version.find_by(tag: "stable.01")) }

  it "moves the saved scenarios of the datasets and the handpicked ones, discarded or not" do
    expect(plan["saved_scenarios"].map { |entry| entry.values_at("id", "reason", "discarded") }).to eq([
      [ moving.id, "dataset:SG_singapore", false ],
      [ discarded.id, "dataset:SG_singapore", true ],
      [ picked.id, "handpicked", false ]
    ])
  end

  it "moves the whole history" do
    expect(plan["saved_scenarios"].first["scenario_ids"]).to eq([ 10, 9, 8 ])
  end

  it "lists the handpicked ids that don't move" do
    expect(plan["skipped"]["handpicked"]).to eq([ { "id" => 999_999, "reason" => "not found" } ])
  end

  it "moves a collection whose saved scenarios all move" do
    collection = collection_with(moving, picked)
    expect(plan["collections"]).to include(a_hash_including("id" => collection.id, "kind" => "saved_scenarios"))
  end

  it "moves a collection in a dataset without saved scenarios" do
    collection = create(:collection, user:, area_code: "SG_singapore", scenarios_count: 2)

    expect(plan["collections"]).to include(a_hash_including(
      "id" => collection.id, "kind" => "direct_only", "scenario_ids" => collection.scenarios.map(&:scenario_id)
    ))
  end

  it "refuses while a collection holds saved scenarios that move and ones that stay" do
    collection = collection_with(moving, staying)

    expect { plan }
      .to raise_error(StableMove::Error, /Collections #{collection.id} \(staying: #{staying.id}\) hold saved scenarios/)
  end

  it "counts the test data the commit would delete" do
    create(:saved_scenario, version: target)
    expect(described_class.summary(JSON.parse(JSON.generate(plan)))["test_data_deleted_at_commit"])
      .to eq("saved_scenarios" => 1, "collections" => 0)
  end

  it "gives ETEngine every scenario to copy" do
    expect(plan["engine"]["scenario_ids"]).to eq([ 8, 9, 10, 11, 30 ])
  end

  it "protects the current scenarios of the kept saved scenarios" do
    expect(plan["engine"]["protect"]).to eq([ 10, 30 ])
  end

  it "refuses to move to a shown version" do
    target.update!(hidden: false)
    expect { plan }.to raise_error(StableMove::Error, /is shown/)
  end

  it "refuses to move to the default version" do
    expect { described_class.call(Version.default, datasets: [ "nl" ]) }.to raise_error(StableMove::Error)
  end
end
