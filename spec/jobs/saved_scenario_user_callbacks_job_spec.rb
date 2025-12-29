# frozen_string_literal: true

RSpec.describe SavedScenarioUserCallbacksJob, type: :job do
  describe '#perform' do
    let(:user) { create(:user) }
    let(:version) { create(:version) }
    let(:saved_scenario) { create(:saved_scenario, user: user, version: version) }
    let(:http_client) { instance_double(Faraday::Connection) }
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
      allow(SavedScenarioUsers::PerformEngineCallbacks).to receive(:call)
    end

    it 'finds the user, saved_scenario, and version' do
      described_class.perform_now(saved_scenario.id, user.id, version.tag, operations)

      expect(MyEtm::Auth).to have_received(:engine_client).with(user, version)
    end

    it 'calls SavedScenarioUsers::PerformEngineCallbacks with correct arguments' do
      described_class.perform_now(saved_scenario.id, user.id, version.tag, operations)

      expect(SavedScenarioUsers::PerformEngineCallbacks).to have_received(:call).with(
        http_client,
        saved_scenario,
        operations: operations,
        historical_only: false
      )
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
