# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FeaturedScenarios API', type: :request do
  let!(:featured_scenarios) { create_list(:featured_scenario, 3) }
  let(:featured_scenario_id) { featured_scenarios.first.id }

  describe 'GET /api/v1/featured_scenarios' do
    context 'without specifying a version' do
      before do
        get '/api/v1/featured_scenarios', as: :json
      end

      it 'returns all featured_scenarios' do
        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['featured_scenarios'].size).to eq(3)

        parsed_response['featured_scenarios'].each do |scenario|
          expect(scenario.keys).to contain_exactly(
            'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en', 'title_nl', 'version', 'end_year', 'author'
          )
          expect(scenario['version']).to eq('latest')
        end
      end
    end

    context 'when specifying a version' do
      before do
        scenario = build(:saved_scenario, version: "old")
        scenario.save(validate: false)
        create(:featured_scenario, saved_scenario: scenario)

        get '/api/v1/featured_scenarios', as: :json, params: { version: "old" }
      end

      it 'returns featured_scenarios that are old' do
        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['featured_scenarios'].size).to eq(1)

        parsed_response['featured_scenarios'].each do |scenario|
          expect(scenario.keys).to contain_exactly(
            'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en', 'title_nl', 'version', 'end_year', 'author'
          )
          expect(scenario['version']).to eq('old')
        end
      end
    end
  end

  describe 'GET /api/v1/featured_scenarios/:id' do
    context 'when the record exists' do
      before { get "/api/v1/featured_scenarios/#{featured_scenario_id}" }

      it 'returns the featured_scenario' do
        expect(response).to have_http_status(:ok)
        parsed_response = JSON.parse(response.body)
        expect(parsed_response.keys).to contain_exactly(
          'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en', 'title_nl', 'version', 'end_year', 'author'
        )
        expect(parsed_response['id']).to eq(featured_scenario_id)
        expect(parsed_response['version']).to eq('latest')
      end
    end

    context 'when the record does not exist' do
      let(:featured_scenario_id) { 0 }
      before do
        get "/api/v1/featured_scenarios/#{featured_scenario_id}", as: :json
      end

      it 'returns a not found message' do
        expect(response).to have_http_status(:not_found)
        parsed_response = JSON.parse(response.body)

        expect(parsed_response.keys).to contain_exactly('error')
        expect(parsed_response['error']).to eq('FeaturedScenario not found')
      end
    end
  end
end
