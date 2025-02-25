# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::Create, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }

  before do
    allow(client).to receive(:put).with(
      '/api/v3/scenarios/1', scenario: { keep_compatible: true }
    )
    allow(client).to receive(:post).with(
      '/api/v3/scenarios/1/version', { :description => "" }
    )
  end

  describe '#call' do
    let(:result) { described_class.call(client, params, user) }

    context 'when given valid params' do
      let(:params) { { scenario_id: 1, area_code: :nl2016, end_year: 2050, title: 'Hey' } }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'returns a SavedScenario' do
        expect(result.value).to be_a(SavedScenario)
      end

      it 'sets the scenario_id' do
        expect(result.value.scenario_id).to eq(1)
      end
    end

    context 'when given no scenario_id' do
      let(:params) { { area_code: :nl2019, end_year: 2050, title: 'Hey' } }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is not successful' do
        expect(result).not_to be_successful
      end
    end

    context 'when the user has private scenarios activated' do
      let(:params) { { scenario_id: 1, area_code: :nl2019, end_year: 2050, title: 'Hey' } }

      before { user.update(private_scenarios: true) }

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'returns a SavedScenario' do
        expect(result.value).to be_a(SavedScenario)
      end

      it 'sets the scenarios privacy' do
        expect(result.value.private).to be_truthy
      end
    end
  end
end
