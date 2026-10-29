# frozen_string_literal: true

RSpec.describe MyEtm::Auth do
  describe '.sign_event' do
    let(:token) { described_class.sign_event({ scenario_id: 1 }, audience: 'collections-events') }
    let(:header) { JWT.decode(token, described_class.signing_key.public_key, true, algorithms: [ 'RS256' ], aud: 'collections-events', verify_aud: true).last }

    it 'names the key the JWKS publishes' do
      expect(header['kid']).to eq(Doorkeeper::OpenidConnect.signing_key.kid)
    end

    # Identity decoders key on the subject and audience; an event must never pass as a credential
    it 'cannot pass as an identity token' do
      expect(described_class.verify_jwt(token)).to be_nil
    end
  end

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

    it 'carries no scenario_access claim by default' do
      expect(decoded).not_to have_key(ScenarioAccess::CLAIM)
    end

    it 'carries the given scenario_access as a claim' do
      payload, = JWT.decode(
        described_class.client_token(user, application, scenario_access: [ [ 1, 'write' ] ]),
        described_class.signing_key.public_key, true, algorithm: 'RS256'
      )
      expect(payload[ScenarioAccess::CLAIM]).to eq('write' => [ 1 ], 'read' => [])
    end
  end

  describe '.scenario_grant' do
    let(:user) { create(:user) }
    let(:saved_scenario) do
      create(:saved_scenario, user: create(:user), scenario_id: 3, scenario_id_history: [ 1, 2 ])
    end

    def grant_with_role(role)
      create(:saved_scenario_user, saved_scenario:, user:, role_id: User::Roles.index_of(role))
      described_class.scenario_grant(user, saved_scenario)
    end

    it 'is nil without a scenario' do
      expect(described_class.scenario_grant(user, nil)).to be_nil
    end

    it 'grants a collaborator write on every Session of the scenario' do
      expect(grant_with_role(:scenario_collaborator).call)
        .to contain_exactly([ 3, 'write' ], [ 2, 'write' ], [ 1, 'write' ])
    end

    it 'grants a viewer read' do
      expect(grant_with_role(:scenario_viewer).call.map(&:last).uniq).to eq([ 'read' ])
    end

    it 'grants nothing without a role' do
      expect(described_class.scenario_grant(user, saved_scenario).call).to be_nil
    end

    it 'grants nothing once the scenario is discarded' do
      grant = grant_with_role(:scenario_owner)
      saved_scenario.discard

      expect(grant.call).to be_nil
    end

    it 'follows a role change made after the client was built' do
      grant = grant_with_role(:scenario_collaborator)
      saved_scenario.saved_scenario_users.find_by(user:).update!(
        role_id: User::Roles.index_of(:scenario_viewer)
      )

      expect(grant.call.map(&:last).uniq).to eq([ 'read' ])
    end

    it 'keeps Sessions dropped and adds Sessions gained after the client was built' do
      grant = grant_with_role(:scenario_owner)
      saved_scenario.restore_historical(1)
      saved_scenario.scenario_id = 4

      expect(grant.call.map(&:first)).to contain_exactly(1, 2, 3, 4)
    end
  end
end
