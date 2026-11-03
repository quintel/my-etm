# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Restore, type: :service do
  let(:user) { create(:user) }
  let(:restore_id) { 1234 }
  let(:result) { described_class.call(saved_scenario, restore_id, user:) }
  let!(:saved_scenario) do
    create(
      :saved_scenario,
      user: user,
      id: 648_695,
      scenario_id_history: [123, 1234, 12_345]
    )
  end

  before { allow(ApiScenario::SetBound).to receive(:call).and_return(Dry::Monads::Success([])) }

  context 'when the restore is succesful' do
    it 'is successful' do
      expect(result).to be_success
    end

    it 'updates the main scenario id' do
      expect { result }.to(change(saved_scenario, :scenario_id))
    end

    it 'has the given scenario id as main scenario id in the resulting saved scenario' do
      expect(result.value!.scenario_id).to eq(restore_id)
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
    before { allow(ApiScenario::SetBound).to receive(:call).and_return(Dry::Monads::Failure([ :upstream, [ 'Engine down' ] ])) }

    it 'passes the upstream failure through' do
      expect(result.failure).to eq([ :upstream, [ 'Engine down' ] ])
    end

    it 'leaves the saved scenario unchanged' do
      expect { result }.not_to(change { saved_scenario.reload.scenario_id })
    end
  end

  context 'when restoring to an unknown scenario id' do
    let(:restore_id) { 999_999 }

    it 'is successful' do
      expect(result).to be_success
    end

    it 'did not change the main scenario id' do
      expect { result }.not_to(change(saved_scenario, :scenario_id))
    end
  end
end
