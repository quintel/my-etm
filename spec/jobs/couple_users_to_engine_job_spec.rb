# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CoupleUsersToEngineJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:user_email) { 'bob@example.com' }
    let(:version) { create(:version) }
    let(:saved_scenario) { create(:saved_scenario, user: user, version: version) }
    let(:http_client) { instance_double(Faraday::Connection) }
    let(:response) { instance_double(Faraday::Response, status: 200) }

    before do
      allow(MyEtm::Auth).to receive(:engine_client).with(user, version).and_return(http_client)
      allow(http_client).to receive(:get).and_return(response)
    end

    it 'couples user to current scenario by triggering User creation in ETEngine' do
      described_class.perform_now(user.id, user_email, [ saved_scenario.id ])

      expect(http_client).to have_received(:get).with(
        "/api/v3/scenarios/#{saved_scenario.scenario_id}"
      )
    end

    context 'when saved_scenario has historical scenarios' do
      let(:historical_ids) { [ 101, 102, 103 ] }

      before do
        saved_scenario.update(scenario_id_history: historical_ids)
      end

      it 'couples user to all historical scenarios' do
        described_class.perform_now(user.id, user_email, [ saved_scenario.id ])

        expect(http_client).to have_received(:get).exactly(4).times
        expect(http_client).to have_received(:get).with(
          "/api/v3/scenarios/#{saved_scenario.scenario_id}"
        )
        historical_ids.each do |scenario_id|
          expect(http_client).to have_received(:get).with(
            "/api/v3/scenarios/#{scenario_id}"
          )
        end
      end
    end

    context 'when scenario is not found' do
      before do
        allow(http_client).to receive(:get).and_raise(Faraday::ResourceNotFound.new('Not found'))
      end

      it 'logs warning and continues' do
        expect do
          described_class.perform_now(user.id, user_email, [ saved_scenario.id ])
        end.not_to raise_error
      end
    end

    context 'when saved_scenario does not exist' do
      it 'silently skips' do
        expect do
          described_class.perform_now(user.id, user_email, [ 999999 ])
        end.not_to raise_error
      end
    end

    context 'when network error occurs' do
      before do
        allow(http_client).to receive(:get).and_raise(Faraday::ConnectionFailed.new('Network error'))
      end

      it 're-raises error to trigger job retry' do
        expect do
          described_class.perform_now(user.id, user_email, [ saved_scenario.id ])
        end.to raise_error(StandardError)
      end
    end
  end
end
