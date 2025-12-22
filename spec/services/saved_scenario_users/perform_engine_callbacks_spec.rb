# frozen_string_literal: true

require 'rails_helper'

RSpec.describe SavedScenarioUsers::PerformEngineCallbacks, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, scenario_id: 100, user: user) }
  let(:operations) do
    [
      {
        type: :create,
        scenario_users: [
          { user_email: 'test@example.com', role: 'scenario_viewer' }
        ]
      }
    ]
  end
  let(:service) do
    described_class.new(http_client, saved_scenario, operations: operations)
  end

  before do
    allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
    allow(ApiScenario::Users::Update).to receive(:call).and_return(ServiceResult.success)
    allow(ApiScenario::Users::Destroy).to receive(:call).and_return(ServiceResult.success)
    allow(saved_scenario).to receive(:scenario_id_history).and_return([ 101, 102 ])
  end

  describe '#call' do
    context 'with create operation' do
      it 'returns a successful ServiceResult' do
        result = service.call
        expect(result).to be_successful
      end

      it 'applies operation to current scenario' do
        service.call

        expect(ApiScenario::Users::Create).to have_received(:call).with(
          http_client,
          100,
          [ hash_including(user_email: 'test@example.com', role: 'scenario_viewer') ]
        )
      end

      it 'applies operation to historical scenarios' do # rubocop:disable RSpec/MultipleExpectations
        service.call

        expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 101, anything)
        expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 102, anything)
      end
    end

    context 'with update operation' do
      let(:operations) do
        [
          {
            type: :update,
            scenario_users: [
              { user_id: 123, role: 'scenario_owner' }
            ]
          }
        ]
      end

      it 'calls ApiScenario::Users::Update' do
        service.call

        expect(ApiScenario::Users::Update).to have_received(:call).with(
          http_client,
          100,
          [ hash_including(user_id: 123, role: 'scenario_owner') ]
        )
      end
    end

    context 'with destroy operation' do
      let(:operations) do
        [
          {
            type: :destroy,
            scenario_users: [
              { user_id: 123, role: 'scenario_viewer' }
            ]
          }
        ]
      end

      it 'calls ApiScenario::Users::Destroy' do
        service.call

        expect(ApiScenario::Users::Destroy).to have_received(:call).with(
          http_client,
          100,
          [ hash_including(user_id: 123) ]
        )
      end
    end

    context 'with multiple operations' do
      let(:operations) do
        [
          {
            type: :create,
            scenario_users: [ { user_email: 'new@example.com', role: 'scenario_viewer' } ]
          },
          {
            type: :update,
            scenario_users: [ { user_id: 123, role: 'scenario_owner' } ]
          }
        ]
      end

      it 'performs all operations' do # rubocop:disable RSpec/MultipleExpectations
        service.call

        expect(ApiScenario::Users::Create).to have_received(:call).at_least(:once)
        expect(ApiScenario::Users::Update).to have_received(:call).at_least(:once)
      end
    end

    context 'with bulk users in a single operation' do
      let(:operations) do
        [
          {
            type: :create,
            scenario_users: [
              { user_email: 'user1@example.com', role: 'scenario_viewer' },
              { user_email: 'user2@example.com', role: 'scenario_collaborator' },
              { user_email: 'user3@example.com', role: 'scenario_owner' }
            ]
          }
        ]
      end

      it 'sends all users in a single API call to current scenario' do
        service.call

        expect(ApiScenario::Users::Create).to have_received(:call).with(
          http_client,
          100,
          array_including(
            hash_including(user_email: 'user1@example.com'),
            hash_including(user_email: 'user2@example.com'),
            hash_including(user_email: 'user3@example.com')
          )
        ).once
      end

      # rubocop:disable RSpec/MultipleExpectations
      it 'sends all users in a single API call to each historical scenario' do
        service.call

        expect(ApiScenario::Users::Create).to have_received(:call).with(
          http_client,
          101,
          array_including(
            hash_including(user_email: 'user1@example.com'),
            hash_including(user_email: 'user2@example.com'),
            hash_including(user_email: 'user3@example.com')
          )
        ).once

        expect(ApiScenario::Users::Create).to have_received(:call).with(
          http_client,
          102,
          array_including(
            hash_including(user_email: 'user1@example.com'),
            hash_including(user_email: 'user2@example.com'),
            hash_including(user_email: 'user3@example.com')
          )
        ).once
      end
      # rubocop:enable RSpec/MultipleExpectations
    end

    context 'when current scenario operation fails' do
      before do
        allow(ApiScenario::Users::Create)
          .to receive(:call)
          .and_return(ServiceResult.failure('Error'))
      end

      it 'does not apply to historical scenarios' do
        service.call

        # Only called once for current scenario, not for historical
        expect(ApiScenario::Users::Create).to have_received(:call).once
      end
    end

    context 'with empty scenario_users' do
      let(:operations) { [ { type: :create, scenario_users: [] } ] }

      it 'skips the operation' do
        service.call

        expect(ApiScenario::Users::Create).not_to have_received(:call)
      end
    end

    context 'with string keys in operations' do
      let(:operations) do
        [
          {
            'type' => 'create',
            'scenario_users' => [
              { 'user_email' => 'test@example.com', 'role' => 'scenario_viewer' }
            ]
          }
        ]
      end

      it 'handles string keys correctly' do
        result = service.call
        expect(result).to be_successful
      end
    end

    context 'when an error occurs' do
      before do
        allow(ApiScenario::Users::Create)
          .to receive(:call)
          .and_raise(StandardError.new('API Error'))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'returns a failure ServiceResult' do # rubocop:disable RSpec/MultipleExpectations
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors.first).to start_with('Failed to perform engine callbacks')
      end

      it 'captures the exception in Sentry' do
        service.call
        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
