# frozen_string_literal: true

require 'rails_helper'

describe UpdateSavedScenarioUser, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:user) { FactoryBot.create(:user) }
  let(:saved_scenario_user) do
    viewer = FactoryBot.create(:saved_scenario_user, role_id: 1, saved_scenario: saved_scenario)
    saved_scenario.saved_scenario_users << viewer

    viewer
  end
  let(:api_result) { ServiceResult.success }
  let(:result) { described_class.call(client, saved_scenario, saved_scenario_user, 2) }
  let!(:saved_scenario) do
    FactoryBot.create(:saved_scenario, user: user, id: 648_695)
  end

  before do
    saved_scenario_user

    allow(ApiScenario::Users::Update).to receive(:call)
      .and_return(api_result)
  end

  context 'when the API responses are successful and the record is valid' do
    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is successful' do
      expect(result).to be_successful
    end

    it 'adds a collaborator on the SavedScenario' do
      expect { result }.to change(
        saved_scenario.collaborators, :count
      ).from(0).to(1)
    end

    it 'removes a viewer on the SavedScenario' do
      expect { result }.to change(
        saved_scenario.viewers, :count
      ).from(1).to(0)
    end
  end

  context 'sync_to_engine' do
    it 'enqueues a sync to ETEngine by default' do
      expect(SavedScenarioUserCallbacksJob).to receive(:perform_later)

      result
    end

    context 'when explicitly disabled' do
      let(:result) do
        described_class.call(client, saved_scenario, saved_scenario_user, 2, sync_to_engine: false)
      end

      it 'does not enqueue a sync to ETEngine' do
        expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

        result
      end
    end
  end

  context 'when downgrading the role of the last owner' do
    let(:saved_scenario_user) { saved_scenario.owners.first }

    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is not successful' do
      expect(result).not_to be_successful
    end

    it 'returns the scenario error messages' do
      expect(result.errors).to eq([ "Last owner cannot be altered" ])
    end

    it 'does not change the owner of the the SavedScenario' do
      expect { result }.not_to change(
        saved_scenario.owners, :count
      )
    end
  end

  # The last-owner guard reads the roles as they stand when each item is saved, so a batch that
  # hands over ownership and steps down depends on ownership being granted before it is given up.
  context 'when one batch transfers ownership and steps down' do
    let(:owner_membership) { saved_scenario.owners.first }
    let(:items) do
      [
        { id: owner_membership.id, role_id: User::Roles.index_of(:scenario_viewer) },
        { id: saved_scenario_user.id, role_id: User::Roles.index_of(:scenario_owner) }
      ]
    end

    let(:result) { described_class.call(client, saved_scenario, items, sync_to_engine: false) }

    it 'applies both items even though the step-down was submitted first' do
      expect(result.items.map(&:ok?)).to eq([ true, true ])
    end

    it 'leaves the scenario with exactly one owner' do
      result

      expect(saved_scenario.owners.reload.map(&:id)).to eq([ saved_scenario_user.id ])
    end

    it 'reports each item at the position it was submitted' do
      expect(result.items.map(&:index)).to eq([ 0, 1 ])
    end
  end
end
