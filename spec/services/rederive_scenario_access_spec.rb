# frozen_string_literal: true

require "rails_helper"

RSpec.describe RederiveScenarioAccess do
  let(:user) { create(:user) }

  def scenario_with_role(session_id, role)
    create(:saved_scenario, scenario_id: session_id).tap do |saved_scenario|
      create(:saved_scenario_user, saved_scenario:, user:, role_id: User::Roles.index_of(role))
    end
  end

  def rederive(pairs)
    described_class.call(ScenarioAccess.new(pairs), user.id).pairs
  end

  it "drops a Session whose role was removed" do
    scenario_with_role(2, :scenario_owner)

    expect(rederive([ [ 1, "write" ], [ 2, "write" ] ])).to eq([ [ 2, "write" ] ])
  end

  it "downgrades a collaborator now a viewer, keeping their place in the order" do
    scenario_with_role(1, :scenario_viewer)
    scenario_with_role(2, :scenario_owner)

    expect(rederive([ [ 1, "write" ], [ 2, "write" ] ])).to eq([ [ 1, "read" ], [ 2, "write" ] ])
  end

  it "upgrades a viewer now a collaborator" do
    scenario_with_role(1, :scenario_collaborator)

    expect(rederive([ [ 1, "read" ] ])).to eq([ [ 1, "write" ] ])
  end

  it "drops a discarded scenario's Session" do
    scenario_with_role(1, :scenario_owner).discard

    expect(rederive([ [ 1, "write" ] ])).to be_empty
  end

  it "drops a Session that has become a snapshot" do
    scenario_with_role(2, :scenario_owner).update!(scenario_id_history: [ 1 ])

    expect(rederive([ [ 1, "write" ] ])).to be_empty
  end

  it "keeps the stronger level when two scenarios hold the Session" do
    scenario_with_role(1, :scenario_viewer)
    scenario_with_role(1, :scenario_owner)

    expect(rederive([ [ 1, "read" ] ])).to eq([ [ 1, "write" ] ])
  end
end
