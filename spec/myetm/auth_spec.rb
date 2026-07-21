# frozen_string_literal: true

RSpec.describe MyEtm::Auth do
  describe '.verify_jwt' do
    let(:user) { create(:user) }

    # The claim contract MyEtm::Auth.verify_jwt enforces, mirroring Identity::TokenDecoder.
    let(:claims) do
      {
        iss: Settings.auth.issuer,
        aud: [Settings.auth.issuer],
        sub: user.id,
        exp: 10.minutes.from_now.to_i,
        scopes: %w[public]
      }
    end

    def sign(payload, signing_key: described_class.signing_key)
      JWT.encode(payload, signing_key, 'RS256', kid: signing_key.to_jwk['kid'])
    end

    let(:token) { sign(claims) }

    it 'returns the claims for a validly-signed token' do
      expect(described_class.verify_jwt(token)['sub']).to eq(user.id)
    end

    it 'returns nil for a token signed by a different key' do
      expect(described_class.verify_jwt(sign(claims, signing_key: OpenSSL::PKey::RSA.new(2048))))
        .to be_nil
    end

    it 'returns nil for garbage input' do
      expect(described_class.verify_jwt('not-a-jwt')).to be_nil
    end

    it 'returns nil for a token issued by someone else' do
      expect(described_class.verify_jwt(sign(claims.merge(iss: 'https://evil.example')))).to be_nil
    end

    it 'returns nil for an expired token' do
      expect(described_class.verify_jwt(sign(claims.merge(exp: 1.minute.ago.to_i)))).to be_nil
    end

    it 'returns nil when the subject is blank' do
      expect(described_class.verify_jwt(sign(claims.merge(sub: nil)))).to be_nil
    end

    # The confused-deputy case: MyETM hands ETEngine short-lived tokens whose audience is ETEngine.
    # Presented back here they must not authenticate, or ETEngine could act as any user at MyETM.
    it 'returns nil for a token audienced at another app' do
      expect(described_class.verify_jwt(sign(claims.merge(aud: ['https://engine.example.com']))))
        .to be_nil
    end

    it 'accepts a token whose audience array includes MyETM' do
      aud = ['https://engine.example.com', Settings.auth.issuer]
      expect(described_class.verify_jwt(sign(claims.merge(aud: aud)))['sub']).to eq(user.id)
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
