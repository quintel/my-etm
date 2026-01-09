# frozen_string_literal: true

RSpec.describe SavedScenarioUserCallbacksJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:version) { create(:version) }
    let(:saved_scenario) { create(:saved_scenario, user: user, version: version, scenario_id: 100) }
    let(:http_client) { instance_double(Faraday::Connection) }
    let(:api_service) { instance_double(ApiScenario::Users::Create) }
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

    before do
      allow(MyEtm::Auth).to receive(:engine_client).with(user, version).and_return(http_client)
      allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
    end

    it 'finds the user, saved_scenario, and version' do
      described_class.perform_now(saved_scenario.id, user.id, version.tag, operations)

      expect(MyEtm::Auth).to have_received(:engine_client).with(user, version)
    end

    it 'calls the API service to apply operations to current scenario' do
      described_class.perform_now(saved_scenario.id, user.id, version.tag, operations)

      expect(ApiScenario::Users::Create).to have_received(:call).with(
        http_client,
        saved_scenario.scenario_id,
        [ { user_email: 'test@example.com', role: 'scenario_viewer' } ]
      )
    end

    context 'with historical scenarios' do
      let(:saved_scenario) do
        create(:saved_scenario, user: user, version: version, scenario_id: 100,
          scenario_id_history: [ 99, 98 ])
      end

      it 'applies operations to all historical scenarios' do
        described_class.perform_now(saved_scenario.id, user.id, version.tag, operations)

        expect(ApiScenario::Users::Create).to have_received(:call).exactly(3).times
        expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 100, anything)
        expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 99, anything)
        expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 98, anything)
      end
    end

    context 'when version tag is not found' do
      it 'uses the default version' do
        default_version = create(:version, tag: 'default')
        allow(Version).to receive(:default).and_return(default_version)
        allow(MyEtm::Auth).to receive(:engine_client).with(user, default_version).and_return(http_client)

        described_class.perform_now(saved_scenario.id, user.id, 'non-existent', operations)

        expect(MyEtm::Auth).to have_received(:engine_client).with(user, default_version)
      end
    end
  end
end
