# frozen_string_literal: true

RSpec.describe MyEtm::Auth do
  describe '.user_jwt' do
    subject do
      JWT.decode(
        described_class.user_jwt(user, scopes: %w[read write]),
        described_class.signing_key.public_key,
        true,
        algorithm: 'RS256'
      )
    end

    before { Settings.etmodel_uri = 'http://etmodel.test' }

    after { Settings.reload! }

    let(:user) { create(:user) }

    let(:payload) { subject[0] }
    let(:header) { subject[1] }

    pending 'returns a JWT for the given user' do
      expect(payload['user']).to eq(user.as_json(only: %i[id name]))
    end

    pending 'includes the scopes in the JWT payload' do
      expect(payload['scopes']).to eq(%w[read write])
    end

    pending 'includes the issuer in the JWT payload' do
    expect(payload['iss']).to eq(Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil))
    end

    pending 'includes the audience in the JWT payload' do
      expect(payload['aud']).to eq(Settings.etmodel_uri)
    end

    pending 'includes the expiration time in the JWT payload' do
      expect(payload['exp']).to be_within(1).of(1.minute.from_now.to_i)
    end

    pending 'includes the issued at time in the JWT payload' do
      expect(payload['iat']).to be_within(1).of(Time.now.to_i)
    end

    pending 'includes the subject in the JWT payload' do
      expect(payload['sub']).to eq(user.id)
    end

    pending 'includes the key ID in the JWT header' do
      expect(header['kid']).to eq(described_class.signing_key.to_jwk['kid'])
    end

    pending 'raises an error when no ETModel URI is set' do
      Settings.etmodel_uri = nil

      expect { described_class.user_jwt(build(:user)) }.to raise_error(
        "No ETModel URI. Please set the 'etmodel_uri' setting in config/settings.local.yml."
      )
    end
  end

  describe '.client_app_client' do
    subject do
      described_class.client_app_client(user, etmodel)
    end

    before { Settings.etmodel_uri = 'http://etmodel.test' }

    after { Settings.reload! }

    let(:user) { create(:user) }

    pending 'sets the scheme for the client' do
      expect(subject.scheme).to eq('http')
    end

    pending 'sets the host for the client' do
      expect(subject.host).to eq('etmodel.test')
    end
  end
end
