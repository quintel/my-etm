# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Restore, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }
  let(:restore_id) { 1234 }
  let(:result) { described_class.call(client, saved_scenario, restore_id, user:) }
  let!(:saved_scenario) do
    create(
      :saved_scenario,
      user: user,
      id: 648_695,
      scenario_id_history: [123, 1234, 12_345]
    )
  end

  before do
    allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([]))
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/12345', scenario: { keep_compatible: false }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/648695', scenario: { keep_compatible: false }
    )
  end

  context 'when the restore is succesful' do
    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is successful' do
      expect(result).to be_successful
    end

    it 'updates the main scenario id' do
      expect { result }.to(change(saved_scenario, :scenario_id))
    end

    it 'has the given scenario id as main scenario id in the resulting saved scenario' do
      expect(result.value.scenario_id).to eq(restore_id)
    end
  end

  it 'unbinds the current Session and the snapshots it drops' do
    result

    expect(ApiScenario::SetBound).to have_received(:call)
      .with(user, saved_scenario.version, [ 648_695, 12_345 ], false)
  end

  context 'when restoring the newest snapshot' do
    let(:restore_id) { 12_345 }

    it 'saves the restored scenario id' do
      expect { result }.to change { saved_scenario.reload.scenario_id }.to(12_345)
    end
  end

  context 'when ETEngine fails to unbind the dropped snapshots' do
    before { allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.failure('Engine down')) }

    it 'is not successful' do
      expect(result).not_to be_successful
    end

    it 'leaves the saved scenario unchanged' do
      expect { result }.not_to(change { saved_scenario.reload.scenario_id })
    end
  end

  context 'when restoring to an unknown scenario id' do
    let(:restore_id) { 999_999 }

    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is successful' do
      expect(result).to be_successful
    end

    it 'did not change the main scenario id' do
      expect { result }.not_to(change(saved_scenario, :scenario_id))
    end
  end
end
