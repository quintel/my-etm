# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedScenarioUsers::Create, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, id: 123, title: 'Test Scenario', user: user) }
  let(:user_params_array) do
    [
      { role_id: 1, user_email: 'user1@example.com' },
      { role_id: 2, user_email: 'user2@example.com' }
    ]
  end
  let(:service) do
    described_class.new(http_client, saved_scenario, user_params_array, user.name, user)
  end

  before do
    allow(SavedScenarioUserCallbacksJob).to receive(:perform_later)
    allow(ScenarioInvitationMailer).to receive(:invite_user).and_call_original
    allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
  end

  describe '#call' do
    context 'when all users are valid' do
      it 'returns a successful ServiceResult' do
        result = service.call
        expect(result).to be_successful
        expect(result.value).to all(be_a(SavedScenarioUser))
        expect(result.value).to all(be_persisted)
      end

      it 'creates the correct number of users' do
        expect { service.call }.to change(saved_scenario.saved_scenario_users, :count).by(2)
      end

      it 'enqueues background job for callbacks' do
        service.call

        expect(SavedScenarioUserCallbacksJob).to have_received(:perform_later).with(
          saved_scenario.id,
          user.id,
          saved_scenario.version.tag,
          [ hash_including(type: :create, scenario_users: array_including(
            hash_including(user_email: 'user1@example.com', role: User::ROLES[1]),
            hash_including(user_email: 'user2@example.com', role: User::ROLES[2])
          )) ]
        )
      end

      it 'sends invitation emails to all users' do
        service.call

        expect(ScenarioInvitationMailer).to have_received(:invite_user).twice
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

    context 'when some users are invalid' do
      let(:user_params_array) do
        [
          { role_id: 1, user_email: 'valid@example.com' },
          { role_id: nil, user_email: nil }  # Invalid
        ]
      end

      it 'returns a failure ServiceResult' do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).not_to be_empty
      end

      it 'creates only valid users' do
        expect { service.call }.to change(saved_scenario.saved_scenario_users, :count).by(1)
      end

      it 'enqueues callbacks for successful users only' do
        service.call
        expect(SavedScenarioUserCallbacksJob).to have_received(:perform_later)
      end

      it 'returns partial success with both successes and errors' do # rubocop:disable RSpec/MultipleExpectations
        result = service.call
        expect(result).not_to be_successful
        expect(result.value).not_to be_empty # Successful users
        expect(result.errors).not_to be_empty # Failed users
      end
    end

    context 'when a duplicate user is provided' do
      before do
        create(:saved_scenario_user, :with_email, saved_scenario: saved_scenario, user_email: 'user1@example.com')
      end

      it 'returns a failure ServiceResult' do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).not_to be_empty
      end

      it 'creates only valid users' do
        expect { service.call }.to change(saved_scenario.saved_scenario_users, :count).by(1)
      end

      it 'enqueues callbacks for successful users only' do
        service.call
        expect(SavedScenarioUserCallbacksJob).to have_received(:perform_later)
      end
    end

    context 'when there is an existing user with the email' do
      let(:existing_user) { create(:user, email: 'existing@example.com') }
      let(:user_params_array) { [ { role_id: 1, user_email: existing_user.email } ] }

      it 'couples the existing user' do
        result = service.call
        expect(result.value.first.user_id).to eq(existing_user.id)
      end
    end
  end
end
