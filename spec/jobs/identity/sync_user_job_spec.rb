# frozen_string_literal: true

RSpec.describe Identity::SyncUserJob, type: :job do
  context 'when Settings.etmodel_uri and Settings.etengine_uri are set' do
    let(:user) { create(:user) }
    let(:versions) { create_list(:version, 3) } # Mocking three versions for the test
    let(:connections) { versions.map { instance_double(Faraday::Connection) } }
    let(:engine_connections) { versions.map { instance_double(Faraday::Connection) } }

    before do
      Settings.etmodel_uri = 'http://example.org'
      Settings.etengine_uri = 'http://example.com'

      allow(Version).to receive(:all).and_return(versions)

      versions.each_with_index do |version, index|
        allow(MyEtm::Auth)
          .to receive(:model_client)
          .with(user, version)
          .and_return(connections[index])

        allow(MyEtm::Auth)
          .to receive(:engine_client)
          .with(user, version)
          .and_return(engine_connections[index])

        allow(connections[index]).to receive(:put)
        allow(engine_connections[index]).to receive(:put)
      end
    end

    after do
      Settings.reload!
    end

    it 'sends a PUT request to the ETModel API for each version' do
      described_class.perform_now(user.id)
      versions.each_with_index do |_, index|
        expect(connections[index]).to have_received(:put).with('/api/v1/user', anything)
      end
    end

    it 'sends a PUT request to the ETEngine API for each version' do
      described_class.perform_now(user.id)
      versions.each_with_index do |_, index|
        expect(engine_connections[index]).to have_received(:put).with('/api/v3/user', anything)
      end
    end

    it 'returns true' do
      expect(described_class.perform_now(user.id)).to be(true)
    end
  end
end
