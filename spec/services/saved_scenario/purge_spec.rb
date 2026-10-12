# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Purge, type: :service do
  let(:user) { create(:user) }
  let!(:saved_scenario) { create(:saved_scenario, user:, scenario_id: 1, scenario_id_history: [ 2 ]) }

  before { allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([])) }

  it 'unbinds every Session' do
    described_class.call(saved_scenario, user)

    expect(ApiScenario::SetBound).to have_received(:call)
      .with(user, saved_scenario.version, [ 1, 2 ], false)
  end

  it 'destroys the scenario' do
    expect { described_class.call(saved_scenario, user) }.to change(SavedScenario, :count).by(-1)
  end

  context 'when ETEngine fails' do
    before do
      allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.failure('Engine down'))
    end

    it 'keeps the scenario' do
      expect { described_class.call(saved_scenario, user) }.not_to change(SavedScenario, :count)
    end

    it 'returns an upstream failure' do
      expect(described_class.call(saved_scenario, user).failure)
        .to eq([ :upstream, [ 'Engine down' ] ])
    end
  end

  context 'when the scenario cannot be destroyed' do
    before { allow(saved_scenario).to receive(:destroy).and_return(false) }

    it 'unbinds nothing' do
      described_class.call(saved_scenario, user)

      expect(ApiScenario::SetBound).not_to have_received(:call)
    end
  end
end
