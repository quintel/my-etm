# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Update, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:saved_scenario) { create(:saved_scenario, scenario_id: 1) }

  before do
    allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([]))
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/2', { scenario: { keep_compatible: true } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/3', { scenario: { keep_compatible: false } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/1', { scenario: { keep_compatible: false } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/2',
      hash_including(
        scenario: hash_including(
          metadata: { saved_scenario_id: saved_scenario.id },
          saved_scenario_users: kind_of(Array)
        )
      )
    )
    allow(client).to receive(:post).with(
      '/api/v3/scenarios/2/version', { description: "" }
    )
  end

  describe '#call' do
    let(:result) { described_class.call(client, saved_scenario, params, user: saved_scenario.users.first) }

    context 'when discarding a scenario' do
      let(:params) { { discarded: true } }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'sets discarded at' do
        expect { result }
          .to change(saved_scenario, :discarded_at)
          .from(nil)
      end

      it 'leaves the Sessions bound in ETEngine' do
        result
        expect(ApiScenario::SetBound).not_to have_received(:call)
      end
    end

    context 'when making a scenario private' do
      let(:params) { { private: true } }

      before do
        saved_scenario.update!(private: false, scenario_id_history: [ 2 ])
        allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids).and_return([ ServiceResult.success ])
      end

      it 'makes every Session private in ETEngine' do
        result
        expect(ApiScenario::UpdatePrivacy).to have_received(:call_with_ids).with(client, [ 1, 2 ], private: true)
      end

      it 'saves the scenario as private' do
        expect { result }.to change { saved_scenario.reload.private }.from(false).to(true)
      end
    end

    context 'when ETEngine fails to change the privacy' do
      let(:params) { { private: true } }

      before do
        saved_scenario.update!(private: false)
        allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids)
          .and_return([ ServiceResult.failure('Engine down') ])
      end

      it 'returns an upstream failure' do
        expect(result.failure).to eq([ :upstream, [ 'Engine down' ] ])
      end

      it 'leaves the scenario public' do
        expect { result }.not_to(change { saved_scenario.reload.private })
      end
    end

    context 'when making a scenario public while pointing it at a new Session' do
      let(:params) { { scenario_id: 2, private: false } }

      before do
        saved_scenario.update!(private: true)
        allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids).and_return([ ServiceResult.success ])
      end

      it 'makes the new Session and the snapshot public in ETEngine' do
        result
        expect(ApiScenario::UpdatePrivacy).to have_received(:call_with_ids).with(client, [ 2, 1 ], private: false)
      end
    end

    context 'when making a scenario public while discarding it' do
      let(:params) { { discarded: true, private: false } }
      let(:kept_when_pushed) { [] }

      before do
        saved_scenario.update!(private: true)
        allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids) do
          kept_when_pushed << saved_scenario.kept?
          [ ServiceResult.success ]
        end
      end

      it 'changes the privacy while the scenario still grants access' do
        result
        expect(kept_when_pushed).to eq([ true ])
      end

      it 'discards the scenario' do
        expect { result }.to change { saved_scenario.reload.discarded? }.from(false).to(true)
      end
    end

    context 'when the privacy is unchanged' do
      let(:params) { { title: 'New title' } }

      before { allow(ApiScenario::UpdatePrivacy).to receive(:call_with_ids) }

      it 'leaves ETEngine alone' do
        result
        expect(ApiScenario::UpdatePrivacy).not_to have_received(:call_with_ids)
      end
    end

    context 'when discarding with an invalid title' do
      let(:params) { { discarded: true, title: '' } }

      it 'leaves the scenario kept' do
        expect { result }.not_to(change { saved_scenario.reload.discarded_at })
      end
    end

    context 'when discarding an already-discarded scenario' do
      let(:params) { { discarded: true } }

      before { saved_scenario.update!(discarded_at: 1.day.ago) }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'sets discarded at' do
        expect { result }
          .not_to change(saved_scenario, :discarded_at)
      end
    end

    context 'when undiscarding scenario' do
      let(:params) { { discarded: false } }

      before { saved_scenario.update!(discarded_at: 1.day.ago) }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'unsets discarded at' do
        expect { result }
          .to change(saved_scenario, :discarded_at)
          .to(nil)
      end

      it 'leaves ETEngine alone' do
        result
        expect(ApiScenario::SetBound).not_to have_received(:call)
      end
    end

    context 'when given a new scenario_id' do
      let(:params) { { scenario_id: 2 } }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'updates the scenario_id' do
        expect { result }
          .to change(saved_scenario, :scenario_id)
          .from(1).to(2)
      end

      it 'adds the old scenario_id to the history' do
        expect { result }
          .to change(saved_scenario, :scenario_id_history)
          .from([]).to([ 1 ])
      end
    end

    context 'when given no scenario_id' do
      let(:params) { { title: 'New title' } }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'does not update the scenario_id' do
        expect { result }
          .not_to change(saved_scenario, :scenario_id)
          .from(1)
      end

      it 'does not update the history' do
        expect { result }
          .not_to change(saved_scenario, :scenario_id_history)
          .from([])
      end
    end

    context 'when given the same scenario_id' do
      let(:params) { { scenario_id: 1, title: 'New title' } }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'does not update the scenario_id' do
        expect { result }
          .not_to change(saved_scenario, :scenario_id)
          .from(1)
      end

      it 'does not update the history' do
        expect { result }
          .not_to change(saved_scenario, :scenario_id_history)
          .from([])
      end
    end

    context 'when given a historical scenario_id' do
      let(:params) { { scenario_id: 2, title: 'New title' } }

      before { saved_scenario.update(scenario_id_history: [ 2, 3 ]) }

      it 'returns a Dry::Monads::Result' do
        expect(result).to be_a(Dry::Monads::Result)
      end

      it 'is successful' do
        expect(result).to be_success
      end

      it 'updates the scenario_id' do
        expect { result }
          .to change(saved_scenario, :scenario_id)
          .from(1).to(2)
      end

      it 'updates the history' do
        expect { result }
          .to change(saved_scenario, :scenario_id_history)
          .from([ 2, 3 ]).to([])
      end
    end
  end
end
