# frozen_string_literal: true

RSpec.describe Identity::SyncUserJob, type: :job do
  context 'when Settings.etmodel_uri is set' do
    let(:user) { create(:user) }
    let(:connection) { instance_double(Faraday::Connection) }
    let(:connection_engine) { instance_double(Faraday::Connection) }

    before do
      Settings.etmodel_uri = 'http://example.org'

      allow(MyEtm::Auth)
        .to receive(:model_client)
        .with(user)
        .and_return(connection)

      allow(MyEtm::Auth)
        .to receive(:engine_client)
        .with(user)
        .and_return(connection_engine)


      allow(connection).to receive(:put)
      allow(connection_engine).to receive(:put)
    end

    after do
      Settings.reload!
    end

    it 'sends a PUT request to the ETModel API' do
      described_class.perform_now(user.id)
      expect(connection).to have_received(:put).with('/api/v1/user', anything)
    end

    it 'sends a PUT request to the ETEngine API' do
      described_class.perform_now(user.id)
      expect(connection_engine).to have_received(:put).with('/api/v3/user', anything)
    end

    it 'returns true' do
      expect(described_class.perform_now(user.id)).to be(true)
    end
  end
end
