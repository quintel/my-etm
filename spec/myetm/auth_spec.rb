# frozen_string_literal: true

RSpec.describe MyEtm::Auth do
  describe '.user_jwt' do
    subject(:decoded_jwt) do
      JWT.decode(
        token,
        described_class.signing_key.public_key,
        true,
        algorithm: 'RS256'
      )
    end

    let(:token) { described_class.user_jwt(user, scopes: scopes, client_id: client_id) }
    let(:user) { create(:user) }
    let(:scopes) { %w[read write] }
    let(:client_id) { 'test-client-id' }

    let(:payload) { decoded_jwt[0] }
    let(:header) { decoded_jwt[1] }

    before do
      Settings.etmodel_uri = 'http://etmodel.test'
    end

    after do
      Settings.reload!
    end

    it 'returns a JWT for the given user' do
      expect(payload['user']).to eq(user.as_json(only: %i[admin id]))
    end

    it 'includes the scopes in the JWT payload' do
      expect(payload['scopes']).to eq(scopes)
    end

    it 'includes the issuer in the JWT payload' do
      expect(payload['iss']).to eq(Doorkeeper::OpenidConnect.configuration.issuer.call(user, nil))
    end

    it 'includes the audience in the JWT payload' do
      expect(payload['aud']).to eq(client_id)
    end

    it 'includes the expiration time in the JWT payload' do
      expected_exp = (Time.now + 1.minute).to_i
      expect(payload['exp']).to be_within(1).of(expected_exp)
    end

    it 'includes the issued at time in the JWT payload' do
      expected_iat = Time.now.to_i
      expect(payload['iat']).to be_within(1).of(expected_iat)
    end

    it 'includes the subject in the JWT payload' do
      expect(payload['sub']).to eq(user.id)
    end

    it 'includes the key ID in the JWT header' do
      expect(header['kid']).to eq(described_class.signing_key.to_jwk['kid'])
    end

    context 'when client_id is not provided' do
      let(:client_id) { nil }

      it 'does not include an audience in the JWT payload' do
        expect(payload['aud']).to eq(nil)
      end
    end
  end
end
