# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::UpsertScenario, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:user) { FactoryBot.create(:user) }
  let(:result) { described_class.call(client, saved_scenario, 10, user:) }
  let(:old_id) { 648_695 }
  let!(:saved_scenario) do
    FactoryBot.create(:saved_scenario,
      user: user,
      id: old_id)
  end

  before do
    allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([]))
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/10', { scenario: { keep_compatible: true } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/oops', { scenario: { keep_compatible: false } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/10',
      hash_including(
        scenario: hash_including(
          metadata: { saved_scenario_id: old_id },
          saved_scenario_users: kind_of(Array)
        )
      )
    )
    allow(client).to receive(:post).with(
      '/api/v3/scenarios/10/version', { description: "" }
    )
  end

  context 'when the API response is successful' do
    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is successful' do
      expect(result).to be_successful
    end

    describe '#value' do
      subject { result.value }

      it { is_expected.to be_a(SavedScenario) }
      it 'contains a new scenario' do
        expect(subject.scenario_id).not_to eq(old_id)
      end
    end

    it 'changes the scenario_id on the SavedScenario' do
      expect { result }.to(
        change(saved_scenario, :scenario_id)
          .from(648_695)
          .to(10)
      )
    end

    it 'changes the scenario_id_history on the SavedScenario' do
      expect { result }.to(
        change(saved_scenario, :scenario_id_history)
          .from([])
          .to([ 648_695 ])
      )
    end
  end

  it 'binds the new Session' do
    result

    expect(ApiScenario::SetBound).to have_received(:call)
      .with(user, saved_scenario.version, [ 10 ], true)
  end

  context 'when the history is full' do
    before { saved_scenario.update!(scenario_id_history: (1..100).to_a) }

    it 'unbinds the snapshot it evicts' do
      result

      expect(ApiScenario::SetBound).to have_received(:call)
        .with(user, saved_scenario.version, [ 1 ], false)
    end
  end

  context 'when ETEngine fails to bind the Session' do
    before { allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.failure('Engine down')) }

    it 'leaves the saved scenario unchanged' do
      expect { result }.not_to(change { saved_scenario.reload.scenario_id })
    end

    it 'is not successful' do
      expect(result).not_to be_successful
    end
  end

  context 'when the scenario ID was faulty' do
    let(:result) { described_class.call(client, saved_scenario, "oops", user:) }

    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is not successful' do
      expect(result).not_to be_successful
    end

    it 'returns the scenario error messages' do
      expect(result.errors).to eq([ "Scenario is not a number" ])
    end
  end
end
