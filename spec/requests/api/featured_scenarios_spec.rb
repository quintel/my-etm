# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'FeaturedScenarios API', type: :request do
  let!(:featured_scenarios) { create_list(:featured_scenario, 3) }
  let(:featured_scenario_id) { featured_scenarios.first.id }

  describe 'GET /api/v1/featured_scenarios' do
    context 'without specifying a version' do
      before { get '/api/v1/featured_scenarios', as: :json }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns all featured scenarios with expected structure' do
        parsed_response = JSON.parse(response.body)

        aggregate_failures do
          expect(parsed_response['featured_scenarios'].size).to eq(3)
          parsed_response['featured_scenarios'].each do |scenario|
            expect(scenario.keys).to contain_exactly(
              'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en',
              'title_nl', 'version', 'end_year', 'author'
            )
          end
        end
      end

      it 'ensures all returned scenarios have the latest version' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['featured_scenarios'].all? { |s|
 s['version'] == 'latest' }).to be(true)
      end
    end

    context 'when specifying a version' do
      let(:version) { create(:version) }

      before do
        scenario = build(:saved_scenario, version: version)
        scenario.save(validate: false)
        create(:featured_scenario, saved_scenario: scenario)

        get '/api/v1/featured_scenarios', as: :json, params: { version: version.tag }
      end

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns only featured scenarios from the specified version' do
        parsed_response = JSON.parse(response.body)

        aggregate_failures do
          expect(parsed_response['featured_scenarios'].size).to eq(1)
          parsed_response['featured_scenarios'].each do |scenario|
            expect(scenario.keys).to contain_exactly(
              'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en',
              'title_nl', 'version', 'end_year', 'author'
            )
          end
        end
      end

      it 'ensures the returned scenario has the correct version' do
        parsed_response = JSON.parse(response.body)
        expect(parsed_response['featured_scenarios'].all? { |s|
 s['version'] == version.tag }).to be(true)
      end
    end
  end

  describe 'GET /api/v1/featured_scenarios/:id' do
    context 'when the record exists' do
      before { get "/api/v1/featured_scenarios/#{featured_scenario_id}" }

      it 'returns a successful response' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns the expected featured scenario details' do
        parsed_response = JSON.parse(response.body)

        aggregate_failures do
          expect(parsed_response.keys).to contain_exactly(
            'id', 'saved_scenario_id', 'owner_id', 'group', 'title_en',
            'title_nl', 'version', 'end_year', 'author'
          )
          expect(parsed_response['id']).to eq(featured_scenario_id)
          expect(parsed_response['version']).to eq('latest')
        end
      end
    end

    context 'when the record does not exist' do
      let(:featured_scenario_id) { 0 }

      before { get "/api/v1/featured_scenarios/#{featured_scenario_id}", as: :json }

      it 'returns a not found response' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns a proper error message' do
        parsed_response = JSON.parse(response.body)

        aggregate_failures do
          expect(parsed_response.keys).to contain_exactly('error')
          expect(parsed_response['error']).to eq('FeaturedScenario not found')
        end
      end
    end
  end
end
