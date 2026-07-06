# frozen_string_literal: true

RSpec.describe MyEtm::Auth do
  describe '.verify_jwt' do
    let(:user) { create(:user) }

    let(:token) do
      key = described_class.signing_key
      JWT.encode({ sub: user.id, scopes: %w[public] }, key, 'RS256', kid: key.to_jwk['kid'])
    end

    it 'returns the claims for a validly-signed token' do
      expect(described_class.verify_jwt(token)['sub']).to eq(user.id)
    end

    it 'returns nil for a token signed by a different key' do
      other_key = OpenSSL::PKey::RSA.new(2048)
      bad_token = JWT.encode({ sub: user.id }, other_key, 'RS256')

      expect(described_class.verify_jwt(bad_token)).to be_nil
    end

    it 'returns nil for garbage input' do
      expect(described_class.verify_jwt('not-a-jwt')).to be_nil
    end
  end

  describe '.client_token' do
    let(:user) { create(:user) }
    let(:application) do
      OAuthApplication.create!(
        name: 'Test App', uri: 'https://example.com', redirect_uri: 'https://example.com/cb',
        owner: user, version: Version.default
      )
    end

    let(:decoded) do
      payload, = JWT.decode(
        described_class.client_token(user, application), described_class.signing_key.public_key,
        true, algorithm: 'RS256'
      )
      payload
    end

    it 'mints a real Doorkeeper access token scoped to the application' do
      expect { described_class.client_token(user, application) }
        .to change { Doorkeeper::AccessToken.count }.by(1)
    end

    it 'returns a JWT for the given user' do
      expect(decoded['sub']).to eq(user.id)
    end

    it "uses the application's own scopes by default" do
      application.update!(scopes: 'public scenarios:read')
      expect(decoded['scopes']).to eq('public scenarios:read')
    end

    it 'uses the given scopes when provided' do
      payload, = JWT.decode(
        described_class.client_token(user, application, scopes: ['scenarios:write']),
        described_class.signing_key.public_key, true, algorithm: 'RS256'
      )
      expect(payload['scopes']).to eq('scenarios:write')
    end

    it 'does not create a refresh token' do
      raw_token = described_class.client_token(user, application)
      expect(Doorkeeper::AccessToken.by_token(raw_token).refresh_token).to be_nil
    end
  end
end
