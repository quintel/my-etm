# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'API::SavedScenarios', type: :request, api: true do
  let(:user) { create(:user) }
  let(:client) { Faraday.new(url: 'http://testing') }

  before { allow(MyEtm::Auth).to receive(:engine_client).and_return(client) }

  describe 'GET /api/v1/saved_scenarios' do
    context 'with an access token with the correct scope' do
      let!(:user_ss1)    { create(:saved_scenario, user: user) }
      let!(:user_ss2)    { create(:saved_scenario, user: user) }
      let!(:other_ss)    { create(:saved_scenario, private: true) }
      let!(:public_ss)   { create(:saved_scenario, private: false) }
      let!(:discarded_ss){ create(:saved_scenario, user: user, discarded_at: 1.day.ago) }

      before do
        get '/api/v1/saved_scenarios',
            as: :json,
            headers: access_token_header(user, :read)
      end

      it 'returns success' do
        expect(response).to have_http_status(:success)
      end

      it 'returns only the current user’s saved scenarios' do
        returned_ids = response.parsed_body.map { |s| s['id'] }
        expect(returned_ids).to match_array([user_ss1.id, user_ss2.id])
      end

      it 'does not contain scenarios from other users or public scenarios' do
        returned_ids = response.parsed_body.map { |s| s['id'] }
        expect(returned_ids).not_to include(other_ss.id, public_ss.id)
      end

      it 'does not contain discarded scenarios' do
        returned_ids = response.parsed_body.map { |s| s['id'] }
        expect(returned_ids).not_to include(discarded_ss.id)
      end

      it 'orders scenarios by updated_at DESC' do
        user_ss2.touch
        get '/api/v1/saved_scenarios',
            as: :json,
            headers: access_token_header(user, :read)

        first_id = JSON.parse(response.body).first['id']
        expect(first_id).to eq(user_ss2.id)
      end
    end

    context 'with an access token with the correct scope, but the user does not exist' do
      let(:request) do
        get '/api/v1/saved_scenarios',
            as: :json,
            headers: access_token_header(user, :read)
      end

      before { user.destroy! }

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end
    end

    context 'without an access token' do
      before do
        get '/api/v1/saved_scenarios', as: :json
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'does not return any scenarios' do
        expect(JSON.parse(response.body)).to be_empty
      end
    end

    context 'with an access token with the incorrect scope' do
      before do
        get '/api/v1/saved_scenarios',
            as: :json,
            headers: access_token_header(user, "string")
      end

      it 'returns ok' do
        expect(response).to have_http_status(:ok)
      end

      it 'does not return any scenarios' do
        expect(JSON.parse(response.body)).to be_empty
      end
    end

    context 'with scope=all param' do
      # current user’s scenarios
      let!(:user_private_ss1) { create(:saved_scenario, user: user, private: true)  }
      let!(:user_private_ss2) { create(:saved_scenario, user: user, private: true)  }
      let!(:user_public_ss)   { create(:saved_scenario, user: user, private: false) }

      # other users’ scenarios
      let!(:other_private_ss) { create(:saved_scenario,               private: true) }
      let!(:other_public_ss)  { create(:saved_scenario,               private: false) }

      # ensure discarded still doesn’t show up
      let!(:discarded_ss)     { create(:saved_scenario, user: user, private: false, discarded_at: 1.day.ago) }

      before do
        get '/api/v1/saved_scenarios',
            params: { scope: 'all' },
            as: :json,
            headers: access_token_header(user, :read)
      end

      it 'returns HTTP success' do
        expect(response).to have_http_status(:success)
      end

      it 'includes all scenarios the user is allowed to read (own + any public)' do
        returned_ids = response.parsed_body.map { |s| s['id'] }
        expect(returned_ids).to match_array([
          user_private_ss1.id,
          user_private_ss2.id,
          user_public_ss.id,
          other_public_ss.id
        ])
      end

      it 'excludes private scenarios of other users and any discarded ones' do
        returned_ids = response.parsed_body.map { |s| s['id'] }
        expect(returned_ids).not_to include(other_private_ss.id, discarded_ss.id)
      end

      it 'orders the results by updated_at descending' do
        user_private_ss1.touch
        other_public_ss.touch

        get '/api/v1/saved_scenarios',
            params: { scope: 'all' },
            as: :json,
            headers: access_token_header(user, :read)

        first_id = response.parsed_body.first['id']
        expect(first_id).to eq(other_public_ss.id)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'GET /api/v1/saved_scenarios/:id' do
    let(:saved_scenario) { create(:saved_scenario, user:) }

    context 'with a valid access token' do
      before do
        get "/api/v1/saved_scenarios/#{saved_scenario.id}",
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns success' do
        expect(response).to have_http_status(:success)
      end

      it 'contains the history' do
        expect(response.parsed_body).to include({ "scenario_id_history" => [] })
      end

      it 'contains the users' do
        users = saved_scenario.saved_scenario_users.map do |ssu|
          { "user_id" => ssu.user_id, "role" => ssu.role.to_s }
        end

        expect(response.parsed_body).to include({ "saved_scenario_users" => users })
      end
    end

    context 'when accessing a private scenario' do
      let(:private_scenario) { create(:saved_scenario, private: true) }

      context 'as an unauthorized user' do
        before do
          get "/api/v1/saved_scenarios/#{private_scenario.id}",
            as: :json,
            headers: access_token_header(user, :read)
        end

        it 'returns not found' do
          expect(response).to have_http_status(:not_found)
        end

        it 'returns an error message' do
          expect(JSON.parse(response.body)).to eq({ "errors" => ["Not found"] })
        end
      end

      context 'as an authorized user' do
        before do
          private_scenario.saved_scenario_users.create!(user: user, role_id: User::Roles.index_of(:scenario_owner))
          get "/api/v1/saved_scenarios/#{private_scenario.id}",
            as: :json,
            headers: access_token_header(user, :read)
        end

        it 'returns success' do
          expect(response).to have_http_status(:success)
        end
      end
    end

    context 'when the scenario does not exist' do
      before do
        get "/api/v1/saved_scenarios/0",
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        expect(JSON.parse(response.body)).to eq({ "errors" => ["Saved scenario not found"] })
      end
    end

    context 'without an access token' do
      before do
        get '/api/v1/saved_scenarios/1', as: :json
      end

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end
    end

    context 'when the scenario belongs to someone else' do
      let(:different_user) { create(:user) }
      let(:private_scenario) { create(:saved_scenario, private: true) }

      before do
        get "/api/v1/saved_scenarios/#{private_scenario.id}",
          as: :json,
          headers: access_token_header(user, :read)
      end

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error message' do
        expect(JSON.parse(response.body)).to eq({ "errors" => ["Not found"] })
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'POST /api/v1/saved_scenarios/:id' do
    let(:request) do
      post '/api/v1/saved_scenarios',
        as: :json,
        params: scenario_attributes,
        headers:
    end

    let(:headers) do
      access_token_header(user, :write)
    end

    let(:scenario_attributes) do
      {
        area_code: 'nl',
        end_year: 2050,
        scenario_id: 1,
        title: 'My scenario'
      }
    end

    before do
      allow(ApiScenario::SetCompatibility).to receive(:call)
      allow(ApiScenario::VersionTags::Create).to receive(:call)
      allow(ApiScenario::SetRoles).to receive(:to_preset)
    end

    context 'when given a valid access token and data, and the user exists' do
      it 'returns created' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates a saved scenario' do
        expect { request }.to change(user.saved_scenarios, :count).by(1)
      end

      it 'returns the scenario' do
        request

        expect(JSON.parse(response.body)).to eq(user.saved_scenarios.last.as_json)
      end
    end

    context 'when given a valid access token and data, but the user does not exist' do
      before do
        user.destroy!
        @headers = access_token_header(nil, :write)
      end

      it 'returns created' do
        request
        expect(response).to have_http_status(:created)
      end

      it 'creates the user' do
        expect { request }.to change(User, :count)
      end

      it 'creates a saved scenario' do
        expect { request }.to change(SavedScenario, :count)
      end
    end

    context 'when given a valid access token and invalid data' do
      before do
        response
        user.destroy!
      end

      let(:scenario_attributes) { super().except(:area_code) }

      it 'returns unprocessable entity' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'does not create a saved scenario' do
        expect { request }.not_to change(user.saved_scenarios, :count)
      end
    end

    context 'when given a token without the scenarios:write scope' do
      before do
        response
        user.destroy!
      end

      let(:headers) do
        access_token_header(user, :read)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end

      it 'does not create a saved scenario' do
        expect { request }.not_to change(user.saved_scenarios, :count)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'PUT /api/v1/saved_scenarios/:id' do
    let(:scenario) do
      create(
        :saved_scenario,
        area_code: 'nl',
        end_year: 2050,
        scenario_id: 1,
        title: 'My scenario',
        user:
      )
    end

    let(:request) do
      put "/api/v1/saved_scenarios/#{scenario.id}",
        as: :json,
        params: scenario_attributes,
        headers: access_token_header(user, :write)
    end

    let(:scenario_attributes) do
      {
        area_code: 'uk',
        end_year: 2060,
        scenario_id: 2,
        title: 'My updated scenario'
      }
    end

    before do
      allow(ApiScenario::SetCompatibility).to receive(:call)
      allow(ApiScenario::VersionTags::Create).to receive(:call)
      allow(ApiScenario::SetRoles).to receive(:to_preset)
    end

    context 'when given a valid access token and data' do
      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'updates the saved scenario' do
        expect { request }
          .to change { scenario.reload.attributes.symbolize_keys.slice(*scenario_attributes.keys) }
          .from(area_code: 'nl', end_year: 2050, scenario_id: 1, title: 'My scenario')
          .to(scenario_attributes)
      end

      it 'adds the previous scenario ID to the history' do
        previous_id = scenario.scenario_id

        expect { request }
          .to change { scenario.reload.scenario_id_history }
          .from([])
          .to([ previous_id ])
      end
    end

    context 'when updating without a scenario ID' do
      let(:scenario_attributes) { super().except(:scenario_id) }

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'does not change the scenario ID history' do
        expect { request }
          .not_to change { scenario.reload.scenario_id_history }
          .from([])
      end

      it 'does not change the scenario ID' do
        expect { request }.not_to change { scenario.reload.scenario_id }
      end
    end

    context 'when updating with the same scenario ID' do
      let(:scenario_attributes) { super().merge(scenario_id: scenario.scenario_id) }

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'does not change the scenario ID history' do
        expect { request }
          .not_to change { scenario.reload.scenario_id_history }
          .from([])
      end
    end

    context 'when updating with a historic scenario ID' do
      before do
        scenario.update(scenario_id_history: [ 999_999, 2, 111_111 ])
        scenario.reload
      end

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'changes the scenario ID history' do
        expect { request }
          .to change { scenario.reload.scenario_id_history }
          .from([ 999_999, 2, 111_111 ]).to([ 999_999 ])
      end

      it 'changes the scenario ID' do
        expect { request }.to change { scenario.reload.scenario_id }.from(1).to(2)
      end
    end

    context 'when given invalid data' do
      let(:scenario_attributes) do
        super().merge(title: '')
      end

      it 'returns unprocessable entity' do
        request
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context 'when the scenario belongs to a different user' do
      let(:request) do
        put "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          params: scenario_attributes,
          headers: access_token_header(create(:user), :write)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when discarding a scenario' do
      let(:request) do
        put "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          params: { saved_scenario: { discarded: true } },
          headers: access_token_header(user, :write)
      end

      it 'is successful' do
        request
        expect(response).to have_http_status(:ok)
      end

      it 'sets the discarded_at timestamp' do
        expect { request }.to change { scenario.reload.discarded_at }.from(nil)
      end
    end

    context 'when discarding an already discarded scenario' do
      let(:request) do
        put "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          params: scenario_attributes.merge(discarded: true),
          headers: access_token_header(user, :write)
      end

      before do
        scenario.update(discarded_at: 1.day.ago)
      end

      it 'sets the discarded_at timestamp' do
        expect { request }.not_to change { scenario.reload.discarded_at }
          .from(scenario.discarded_at)
      end
    end

    context 'when undiscarding a scenario' do
      let(:request) do
        put "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          params: { saved_scenario: { discarded: false } },
          headers: access_token_header(user, :write)
      end

      before do
        scenario.update(discarded_at: 1.day.ago)
      end

      it 'sets the discarded_at timestamp' do
        expect { request }.to change { scenario.reload.discarded_at }
          .from(scenario.discarded_at)
          .to(nil)
      end
    end

    context 'when undiscarding a non-discarded scenario' do
      let(:request) do
        put "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          params: scenario_attributes.merge(discarded: false),
          headers: access_token_header(user, :write)
      end

      it 'sets the discarded_at timestamp' do
        expect { request }.not_to change { scenario.reload.discarded_at }.from(nil)
      end
    end
  end

  # ------------------------------------------------------------------------------------------------

  describe 'DELETE /api/v1/saved_scenarios/:id' do
    let!(:scenario) { create(:saved_scenario, user:) }

    context 'when the scenario belongs to the user' do
      let(:request) do
        delete "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          headers: access_token_header(user, :delete)
      end

      it 'returns success' do
        request
        expect(response).to have_http_status(:success)
      end

      it 'removes the scenario' do
        expect { request }.to change(user.saved_scenarios, :count).by(-1)
      end

      it 'returns a success message' do
        request
        expect(JSON.parse(response.body)).to include('message' => 'Scenario deleted successfully')
      end
    end

    context 'when the deletion fails' do
      before do
        allow_any_instance_of(SavedScenario).to receive(:destroy).and_return(false)
        delete "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          headers: access_token_header(user, :delete)
      end

      it 'returns unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_entity)
      end

      it 'returns an error message' do
        expect(JSON.parse(response.body)).to include('error' => 'Failed to delete scenario')
      end
    end

    context 'when missing the scenarios:delete scope' do
      let(:request) do
        delete "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          headers: access_token_header(user, :write)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end

    context 'when the scenario belongs to a different user' do
      let(:request) do
        delete "/api/v1/saved_scenarios/#{scenario.id}",
          as: :json,
          headers: access_token_header(create(:user), :delete)
      end

      it 'returns forbidden' do
        request
        expect(response).to have_http_status(:forbidden)
      end
    end
  end
end
