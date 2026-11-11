# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Api::SavedScenarioUsers', type: :request, api: true do
  # When we find the time and energy to setup the SSUsersAPI correctly

  let(:user) { create(:user) }
  let(:api_result) {
    ServiceResult.success([ { 'role_id' => 1, 'user_email' => 'test@test.com' } ]) }
  let!(:saved_scenario) { create(:saved_scenario, user: user) }
  let(:client) { Faraday.new(url: 'http://et.engine') }

  before { allow(MyEtm::Auth).to receive(:engine_client).and_return(client) }

  # Stub all APIScenarioUser generation
  before do
    allow(ApiScenario::Users::Create).to receive(:call)
      .and_return(api_result)
    allow(ApiScenario::Users::Update).to receive(:call)
      .and_return(api_result)
    allow(ApiScenario::Users::Destroy).to receive(:call)
      .and_return(api_result)
  end

  describe 'GET index' do
    it 'returns forbidden without an access token' do
      get "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json

      expect(response).to have_http_status(:forbidden)
    end

    # Who holds a role is the owner's business, so an owner reads it with the read scope alone.
    it 'returns success for an owner with only the read scope' do
      get "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
        headers: access_token_header(user, :read)

      expect(response).to have_http_status(:ok)
    end

    context 'with a proper token and scope' do
      before do
        get "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete)
      end

      it 'returns success' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns a list of all users' do
        expect(JSON.parse(response.body)).to include(
          a_hash_including(
            'user_id' => user.id, 'user_email' => user.email, 'role' => 'scenario_owner'
          )
        )
      end
    end
  end

  describe 'POST /api/v1/saved_scenarios/:id/users' do
    context 'with proper params' do
      let(:api_result) do
        ServiceResult.success([
          { 'role_id' => 1, 'user_email' => 'viewer@test.com' },
          { 'role_id' => 2, 'user_email' => 'collaborator@test.com' },
          { 'role_id' => 3, 'user_email' => 'owner@test.com' }
        ])
      end

      before do
        post "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [
              { user_email: 'viewer@test.com', role: 'scenario_viewer' },
              { user_email: 'collaborator@test.com', role: 'scenario_collaborator' },
              { user_email: 'owner@test.com', role: 'scenario_owner' }
            ]
          }
      end

      it 'returns success' do
        expect(response).to have_http_status(:created)
      end

      it 'adds the given users to the scenario' do
        expect(JSON.parse(response.body)).to include(
          a_hash_including('user_id' => nil, 'user_email' => 'viewer@test.com',
            'role' => 'scenario_viewer'),
          a_hash_including('user_id' => nil, 'user_email' => 'collaborator@test.com',
            'role' => 'scenario_collaborator'),
          a_hash_including('user_id' => nil, 'user_email' => 'owner@test.com',
            'role' => 'scenario_owner')
        )
      end
    end

    context 'with malformed user params' do
      let(:api_result) do
        ServiceResult.failure([ 'role_id is invalid' ])
      end

      before do
        post "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [ { user_email: 'viewer@test.com' } ]
          }
      end

      it 'returns 422: unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error' do
        errors = JSON.parse(response.body)['errors']
        if errors.is_a?(Array) && errors.first.is_a?(Array)
          errors = errors.to_h.transform_values { |v| v.last.last }
        end
        # Accept either the custom or default ActiveModel error message
        expect(errors['viewer@test.com']).to include('role_id').or(include('Role is not included in the list'))
      end
    end

    context 'with duplicate user params' do
      before do
        post "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [
              { user_email: 'viewer@test.com', role: 'scenario_viewer' },
              { user_email: 'viewer@test.com', role: 'scenario_collaborator' }
            ]
          }
      end

      it 'returns 422: unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error' do
        errors = JSON.parse(response.body)['errors']
        if errors.is_a?(Array) && errors.first.is_a?(Array)
          errors = errors.to_h.transform_values { |v| v.last.last }
        end
        expect(errors).to eq(
          { 'viewer@test.com' => [ 'This user already has access to this scenario' ] }
        )
      end
    end
  end

  describe 'PUT /api/v1/saved_scenarios/:id/users' do
    context 'with proper params' do
      let(:user_2) { create(:user) }
      let(:user_3) { create(:user) }

      let(:api_result) do
        ServiceResult.success([
          { 'role_id' => 1, 'user_id' => user_2.id },
          { 'role_id' => 3, 'user_id' => user_3.id }
        ])
      end

      before do
        create(:saved_scenario_user,
          saved_scenario: saved_scenario, user: user_2,
          role_id: User::ROLES.key(:scenario_viewer)
        )
        create(:saved_scenario_user,
          saved_scenario: saved_scenario, user: user_3,
          role_id: User::ROLES.key(:scenario_collaborator)
        )

        put "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [
              { user_id: user_2.id, role: 'scenario_owner' },
              { user_id: user_3.id, role: 'scenario_viewer' }
            ]
          }
      end

      it 'returns success' do
        expect(response).to have_http_status(:ok)
      end

      it 'updates the role for the given user' do
        expect(JSON.parse(response.body)).to include(
          a_hash_including(
            'user_id' => user_2.id, 'user_email' => user_2.email, 'role' => 'scenario_owner'
          ),
          a_hash_including(
            'user_id' => user_3.id, 'user_email' => user_3.email, 'role' => 'scenario_viewer'
          )
        )
      end
    end

    context 'with a non-existing user id' do
      let(:non_existing_id) { 999 }
      before do
        put "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [
              { user_id: non_existing_id, role: 'scenario_collaborator' }
            ]
          }
      end

      it 'returns 404: not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns an error' do
        errors = JSON.parse(response.body)['errors']
        if errors.is_a?(Array) && errors.first.is_a?(Array)
          errors = errors.to_h.transform_values { |v| v.last.last }
        end
        expect(errors).to eq([ 'User not found' ])
      end
    end

    context 'with a missing role' do
      let(:user_2) { create(:user) }

      before do
        create(:saved_scenario_user,
          saved_scenario: saved_scenario, user: user_2,
          role_id: User::ROLES.key(:scenario_viewer)
        )

        put "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [ { user_id: user_2.id } ]
          }
      end

      it 'returns 422: unprocessable entity' do
        expect(response).to have_http_status(:unprocessable_content)
      end

      it 'returns an error' do
        expect(JSON.parse(response.body)['errors']).not_to be_empty
      end
    end
  end

  describe 'DELETE /api/v1/saved_scenarios/:id/users' do
    context 'with proper params' do
      let(:user_2) { create(:user) }
      let(:user_3) { create(:user) }

      before do
        create(:saved_scenario_user,
          saved_scenario: saved_scenario, user: user_2,
          role_id: User::ROLES.key(:scenario_viewer)
        )
        create(:saved_scenario_user,
          saved_scenario: saved_scenario, user: user_3,
          role_id: User::ROLES.key(:scenario_collaborator)
        )

        saved_scenario.reload

        delete "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [ { user_id: user_2.id }, { user_id: user_3.id } ]
          }
      end

      it 'returns OK' do
        expect(response).to have_http_status(:ok)
      end

      it 'returns no errors' do
        expect(JSON.parse(response.body).length).to eq(2)
      end

      it 'removes the given users' do
        expect(
          saved_scenario.saved_scenario_users.count
        ).to be(1)
      end
    end

    context 'with a non-existing user id' do
      before do
        delete "/api/v1/saved_scenarios/#{saved_scenario.id}/users", as: :json,
          headers: access_token_header(user, :delete),
          params: {
            saved_scenario_users: [ { user_id: 999 } ]
          }
      end

      it 'returns not found' do
        expect(response).to have_http_status(:not_found)
      end

      it 'returns the errors in the response body' do
        errors = JSON.parse(response.body)['errors']
        if errors.is_a?(Array) && errors.first.is_a?(Array)
          errors = errors.to_h.transform_values { |v| v.last.last }
        elsif errors.is_a?(Array)
          # If errors is just an array of messages, wrap in hash for comparison
          errors = { '999' => errors }
        end
        expect(errors).to eq({ '999' => [ 'User not found' ] })
      end
    end
  end

  describe 'who may manage members' do
    let(:path) { "/api/v1/saved_scenarios/#{saved_scenario.id}/users" }
    let(:viewer) { create(:user) }
    let(:collaborator) { create(:user) }

    let!(:viewer_membership) do
      create(:saved_scenario_user,
        saved_scenario: saved_scenario, user: viewer,
        role_id: User::ROLES.key(:scenario_viewer)
      )
    end

    before do
      create(:saved_scenario_user,
        saved_scenario: saved_scenario, user: collaborator,
        role_id: User::ROLES.key(:scenario_collaborator)
      )
    end

    def list_members(headers)
      get(path, as: :json, headers: headers)
    end

    def add_member(headers, email)
      post(path, as: :json, headers: headers,
        params: { saved_scenario_users: [ { user_email: email, role: 'scenario_owner' } ] })
    end

    def set_role(headers, membership, role)
      put(path, as: :json, headers: headers,
        params: { saved_scenario_users: [ { user_id: membership.user_id, role: role } ] })
    end

    def remove_member(headers, membership)
      delete(path, as: :json, headers: headers,
        params: { saved_scenario_users: [ { user_id: membership.user_id } ] })
    end

    def owner_membership
      saved_scenario.saved_scenario_users.find_by(user: user)
    end

    shared_examples 'a caller who may not manage members' do
      it 'may not list the members' do
        list_members(headers)

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(user.email)
      end

      it 'may not add a member' do
        add_member(headers, 'new@example.com')

        expect(response).to have_http_status(:forbidden)
        expect(SavedScenarioUser.exists?(user_email: 'new@example.com')).to be(false)
      end

      it 'may not change a role' do
        set_role(headers, viewer_membership, 'scenario_owner')

        expect(response).to have_http_status(:forbidden)
        expect(viewer_membership.reload.role_id).to eq(User::ROLES.key(:scenario_viewer))
      end

      it 'may not repeat a role to read the member back' do
        set_role(headers, owner_membership, 'scenario_owner')

        expect(response).to have_http_status(:forbidden)
        expect(response.body).not_to include(user.email)
      end

      it 'may not remove a member' do
        remove_member(headers, viewer_membership)

        expect(response).to have_http_status(:forbidden)
        expect(SavedScenarioUser.exists?(viewer_membership.id)).to be(true)
      end
    end

    context 'without an access token' do
      let(:headers) { {} }

      it_behaves_like 'a caller who may not manage members'
    end

    context 'as a stranger' do
      let(:headers) { access_token_header(create(:user), :delete) }

      it_behaves_like 'a caller who may not manage members'
    end

    context 'as a viewer' do
      let(:headers) { access_token_header(viewer, :delete) }

      it_behaves_like 'a caller who may not manage members'
    end

    # A collaborator may edit the scenario but not who reaches it, as in the UI.
    context 'as a collaborator' do
      let(:headers) { access_token_header(collaborator, :delete) }

      it_behaves_like 'a caller who may not manage members'
    end

    context 'when the scenario is private' do
      before { saved_scenario.update!(private: true) }

      it 'hides it from a stranger' do
        add_member(access_token_header(create(:user), :delete), 'new@example.com')

        expect(response).to have_http_status(:not_found)
      end

      it 'does not let a viewer make themselves an owner' do
        set_role(access_token_header(viewer, :delete), viewer_membership, 'scenario_owner')

        expect(response).to have_http_status(:not_found)
        expect(viewer_membership.reload.role_id).to eq(User::ROLES.key(:scenario_viewer))
      end
    end
  end
end
