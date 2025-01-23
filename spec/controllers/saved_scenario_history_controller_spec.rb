# frozen_string_literal: true

require 'rails_helper'

describe SavedScenarioHistoryController, vcr: true do
  render_views

  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: user, scenario_id: 123, scenario_id_history: [111, 122]) }
  let(:client) { Faraday.new(url: 'http://et.engine') }

  before do
    allow(ApiScenario::VersionTags::Update).to receive(:call).and_return(
      ServiceResult.success(
        {
          'user_id' => user.id,
          'description' => 'my last version',
          'last_updated_at' => 2.days.ago.to_json
        }
      )
    )
    allow(ApiScenario::VersionTags::FetchAll).to receive(:call).and_return(ServiceResult.success(
      {
        "123" => {
          'user_id' => user.id,
          'description' => 'my last version',
          'last_updated_at' => 2.days.ago.to_json
        },
        "122" => {},
        "111" => {}
      }
    ))
    allow(MyEtm::Auth).to receive(:engine_client).and_return(client)
  end

  context 'with a user that owns the scenario' do
    before do
      sign_in user
    end

    describe 'GET index' do
      before do
        get :index, params: {
          saved_scenario_id: saved_scenario.id
        }
      end

      it 'is succesful' do
        expect(response).to be_ok
      end
    end

    describe 'PUT update' do
      before do
        put :update, format: :turbo_stream, params: {
          saved_scenario_id: saved_scenario.id,
          scenario_id: saved_scenario.scenario_id,
          saved_scenario_history: { description: 'my update' }
        }
      end

      it 'is succesful' do
        expect(response).to be_ok
      end
    end
  end
end
