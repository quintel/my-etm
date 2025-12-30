# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CleanupScenarioUsersJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:version) { create(:version) }
    let(:scenario_ids) { [ 123, 456, 789 ] }
    let(:http_client) { instance_double(Faraday::Connection) }
    let(:success_response) { instance_double(Faraday::Response, success?: true) }

    before do
      allow(MyEtm::Auth).to receive(:engine_client).with(user, version).and_return(http_client)
      allow(http_client).to receive(:delete).and_return(success_response)
    end

    it 'deletes ScenarioUsers for all provided scenario IDs' do
      described_class.perform_now(user.id, version.id, scenario_ids)

      scenario_ids.each do |scenario_id|
        expect(http_client).to have_received(:delete).with("/api/v3/scenarios/#{scenario_id}/users")
      end
    end

    context 'when deletion fails' do
      let(:failed_response) {
 instance_double(Faraday::Response, success?: false, body: 'Error message') }

      before do
        allow(http_client).to receive(:delete).and_return(failed_response)
        allow(Sentry).to receive(:capture_message)
      end

      it 'captures failure in Sentry' do
        described_class.perform_now(user.id, version.id, scenario_ids)

        expect(Sentry).to have_received(:capture_message).exactly(3).times
        expect(Sentry).to have_received(:capture_message).with(
          "Failed to cleanup ScenarioUsers for scenario 123: Error message",
          level: :warning
        )
      end
    end

    context 'when scenario is not found' do
      before do
        allow(http_client).to receive(:delete).and_raise(Faraday::ResourceNotFound.new('Not found'))
      end

      it 'silently continues' do
        expect do
          described_class.perform_now(user.id, version.id, scenario_ids)
        end.not_to raise_error
      end
    end

    context 'when network error occurs' do
      before do
        allow(http_client).to receive(:delete).and_raise(Faraday::ConnectionFailed.new('Network error'))
        allow(Sentry).to receive(:capture_exception)
      end

      it 'captures exception and re-raises for retry' do
        expect do
          described_class.perform_now(user.id, version.id, scenario_ids)
        end.to raise_error(StandardError)

        expect(Sentry).to have_received(:capture_exception)
      end
    end
  end
end
