# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedScenarioUsers::Update, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: user) }
  let!(:scenario_user1) { create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1) }
  let!(:scenario_user2) { create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1) }
  let(:user_params_array) do
    [
      { id: scenario_user1.id, role_id: 2 },
      { user_id: scenario_user2.user_id, role_id: 3 }
    ]
  end
  let(:service) do
    described_class.new(http_client, saved_scenario, user_params_array, user)
  end

  before do
    allow(SavedScenarioUserCallbacksJob).to receive(:perform_later)
    allow(ApiScenario::Users::Update).to receive(:call).and_return(ServiceResult.success)
  end

  describe '#call' do
    context 'when all updates are valid' do
      it 'returns a successful ServiceResult' do
        result = service.call
        expect(result).to be_successful
        expect(result.value).to all(be_a(SavedScenarioUser))
      end

      it 'updates user roles' do
        service.call
        expect(scenario_user1.reload.role_id).to eq(2)
        expect(scenario_user2.reload.role_id).to eq(3)
      end

      it 'enqueues background job for callbacks' do
        service.call

        expect(SavedScenarioUserCallbacksJob).to have_received(:perform_later).with(
          saved_scenario.id,
          user.id,
          saved_scenario.version.tag,
          [ hash_including(type: :update, scenario_users: array_including(
            hash_including(user_id: scenario_user1.user_id, role: User::ROLES[2]),
            hash_including(user_id: scenario_user2.user_id, role: User::ROLES[3])
          )) ]
        )
      end
    end

    context 'when no users provided' do
      let(:user_params_array) { [] }

      it 'returns a failure ServiceResult' do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to eq([ 'No users provided' ])
      end

      it 'does not enqueue callbacks' do
        service.call
        expect(SavedScenarioUserCallbacksJob).not_to have_received(:perform_later)
      end
    end

    context 'when user is not found' do
      let(:user_params_array) { [ { id: 99999, role_id: 2 } ] }

      it 'returns a failure ServiceResult' do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).not_to be_empty
      end

      it 'does not enqueue callbacks' do
        service.call
        expect(SavedScenarioUserCallbacksJob).not_to have_received(:perform_later)
      end
    end

    context 'when finding user by email' do
      let!(:scenario_user3) { create(:saved_scenario_user, :with_email, saved_scenario: saved_scenario, user_email: 'test@example.com') }
      let(:user_params_array) { [ { user_email: 'test@example.com', role_id: 2 } ] }

      it 'finds and updates the user' do
        result = service.call
        expect(result).to be_successful
        expect(scenario_user3.reload.role_id).to eq(2)
      end
    end
  end
end
