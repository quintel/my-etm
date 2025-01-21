# frozen_string_literal: true

RSpec.describe Identity::DestroyUserJob, type: :job do
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

        allow(connections[index]).to receive(:delete)
        allow(engine_connections[index]).to receive(:delete)
      end
    end

    after do
      Settings.reload!
    end

    it 'sends a DELETE request to the ETModel API for each version' do
      described_class.perform_now(user.id)
      versions.each_with_index do |_, index|
        expect(connections[index]).to have_received(:delete).with('/api/v1/user')
      end
    end

    it 'sends a DELETE request to the ETEngine API for each version' do
      described_class.perform_now(user.id)
      versions.each_with_index do |_, index|
        expect(engine_connections[index]).to have_received(:delete).with('/api/v3/user')
      end
    end

    it 'destroys the user' do
      expect { described_class.perform_now(user.id) }
        .to change { User.where(id: user.id).count }.by(-1)
    end

    it 'returns true' do
      expect(described_class.perform_now(user.id)).to be(true)
    end
  end
end
