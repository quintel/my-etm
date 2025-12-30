# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Update, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:saved_scenario) { create(:saved_scenario, scenario_id: 1) }

  before do
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/2', { scenario: { keep_compatible: true } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/3', { scenario: { keep_compatible: false } }
    )
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/2',
      {
        scenario: {
          set_preset_roles: true,
          metadata: { saved_scenario_id: saved_scenario.id }
        }
      }
    )
    allow(client).to receive(:post).with(
      '/api/v3/scenarios/2/version', { description: "" }
    )
  end

  describe '#call' do
    let(:result) { described_class.call(client, saved_scenario, params) }

    context 'when discarding a scenario' do
      let(:params) { { discarded: true } }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'sets discarded at' do
        expect { result }
          .to change(saved_scenario, :discarded_at)
          .from(nil)
      end
    end

    context 'when discarding an already-discarded scenario' do
      let(:params) { { discarded: true } }

      before { saved_scenario.update!(discarded_at: 1.day.ago) }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'sets discarded at' do
        expect { result }
          .not_to change(saved_scenario, :discarded_at)
      end
    end

    context 'when undiscarding scenario' do
      let(:params) { { discarded: false } }

      before { saved_scenario.update!(discarded_at: 1.day.ago) }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'unsets discarded at' do
        expect { result }
          .to change(saved_scenario, :discarded_at)
          .to(nil)
      end
    end

    context 'when given a new scenario_id' do
      let(:params) { { scenario_id: 2 } }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
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

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
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

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
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

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
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
