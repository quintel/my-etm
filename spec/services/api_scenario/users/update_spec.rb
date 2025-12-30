# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ApiScenario::Users::Update, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:scenario_id) { 100 }
  let(:response_body) { [ { id: 1, user_email: 'test@example.com', role: 'scenario_owner' } ] }
  let(:response) { instance_double(Faraday::Response, body: response_body) }

  describe '#call' do
    context 'with an array of users' do
      let(:scenario_users) do
        [
          { user_id: 1, role: 'scenario_owner' },
          { user_id: 2, role: 'scenario_collaborator' }
        ]
      end
      let(:service) { described_class.new(http_client, scenario_id, scenario_users) }
      let(:response_body) do
        [
          { id: 1, user_id: 1, role: 'scenario_owner' },
          { id: 2, user_id: 2, role: 'scenario_collaborator' }
        ]
      end

      it 'sends array directly in API call' do # rubocop:disable RSpec/MultipleExpectations
        expect(http_client).to receive(:put).with(
          "/api/v3/scenarios/#{scenario_id}/users",
          { scenario_users: scenario_users }
        ).and_return(response)

        result = service.call
        expect(result).to be_successful
        expect(result.value).to eq(response_body)
      end
    end

    context 'when scenario is not found' do
      let(:scenario_users) { [ { user_id: 1, role: 'scenario_owner' } ] }
      let(:service) { described_class.new(http_client, scenario_id, scenario_users) }

      it 'returns a failure result' do # rubocop:disable RSpec/MultipleExpectations
        allow(http_client).to receive(:put).and_raise(Faraday::ResourceNotFound.new('not found'))

        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to include('Scenario not found')
      end
    end

    context 'when access is forbidden' do
      let(:scenario_users) { [ { user_id: 1, role: 'scenario_owner' } ] }
      let(:service) { described_class.new(http_client, scenario_id, scenario_users) }

      it 'returns a failure result' do # rubocop:disable RSpec/MultipleExpectations
        allow(http_client).to receive(:put).and_raise(Faraday::ForbiddenError.new('forbidden'))

        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to include('No access to this scenario')
      end
    end
  end
end
