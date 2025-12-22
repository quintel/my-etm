# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiScenario::Users::Create, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:scenario_id) { 100 }
  let(:response_body) { [ { id: 1, user_email: 'test@example.com', role: 'scenario_viewer' } ] }
  let(:response) { instance_double(Faraday::Response, body: response_body) }

  describe '#call' do
    context 'with a single user hash' do
      let(:scenario_user) { { user_email: 'test@example.com', role: 'scenario_viewer' } }
      let(:service) { described_class.new(http_client, scenario_id, scenario_user) }

      it 'normalizes single user to array and makes API call' do # rubocop:disable RSpec/MultipleExpectations
        expect(http_client).to receive(:post).with(
          "/api/v3/scenarios/#{scenario_id}/users",
          { scenario_users: [ scenario_user ] }
        ).and_return(response)

        result = service.call
        expect(result).to be_successful
        expect(result.value).to eq(response_body)
      end
    end

    context 'with an array of users' do
      let(:scenario_users) do
        [
          { user_email: 'user1@example.com', role: 'scenario_viewer' },
          { user_email: 'user2@example.com', role: 'scenario_collaborator' }
        ]
      end
      let(:service) { described_class.new(http_client, scenario_id, scenario_users) }
      let(:response_body) do
        [
          { id: 1, user_email: 'user1@example.com', role: 'scenario_viewer' },
          { id: 2, user_email: 'user2@example.com', role: 'scenario_collaborator' }
        ]
      end

      it 'sends array directly in API call' do # rubocop:disable RSpec/MultipleExpectations
        expect(http_client).to receive(:post).with(
          "/api/v3/scenarios/#{scenario_id}/users",
          { scenario_users: scenario_users }
        ).and_return(response)

        result = service.call
        expect(result).to be_successful
        expect(result.value).to eq(response_body)
      end
    end

    context 'when scenario is not found' do
      let(:scenario_user) { { user_email: 'test@example.com', role: 'scenario_viewer' } }
      let(:service) { described_class.new(http_client, scenario_id, scenario_user) }

      it 'returns a failure result' do # rubocop:disable RSpec/MultipleExpectations
        allow(http_client).to receive(:post).and_raise(Faraday::ResourceNotFound.new('not found'))

        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to include('Scenario not found')
      end
    end

    context 'when validation fails' do
      let(:scenario_user) { { user_email: 'invalid', role: 'invalid_role' } }
      let(:service) { described_class.new(http_client, scenario_id, scenario_user) }

      it 'returns a failure result with errors' do
        error_response = instance_double(Faraday::Response)
        allow(error_response).to receive(:[]).with(:body).and_return('errors' => { 'invalid' => [ 'role_id' ] })

        allow(http_client).to receive(:post).and_raise(
          Faraday::UnprocessableEntityError.new(nil, error_response)
        )

        result = service.call
        expect(result).not_to be_successful
      end
    end
  end
end
