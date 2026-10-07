# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::SetDiscarded, type: :service do
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user:, scenario_id: 1, scenario_id_history: [ 2 ]) }

  before { allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([])) }

  it 'unbinds every Session when discarding' do
    described_class.call(saved_scenario, true, user)

    expect(ApiScenario::SetBound).to have_received(:call)
      .with(user, saved_scenario.version, [ 1, 2 ], false)
  end

  it 'binds every Session again when undiscarding' do
    saved_scenario.update!(discarded_at: 1.day.ago)
    described_class.call(saved_scenario, false, user)

    expect(ApiScenario::SetBound).to have_received(:call)
      .with(user, saved_scenario.version, [ 1, 2 ], true)
  end

  it 'calls nothing when the scenario is invalid' do
    saved_scenario.update_column(:title, '')
    described_class.call(saved_scenario, true, user)

    expect(ApiScenario::SetBound).not_to have_received(:call)
  end

  context 'when ETEngine fails' do
    before do
      allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.failure('Engine down'))
    end

    it 'leaves the scenario kept' do
      expect { described_class.call(saved_scenario, true, user) }
        .not_to(change { saved_scenario.reload.discarded_at })
    end

    it 'returns an upstream failure' do
      expect(described_class.call(saved_scenario, true, user).failure)
        .to eq([ :upstream, [ 'Engine down' ] ])
    end
  end
end
