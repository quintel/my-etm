# frozen_string_literal: true

RSpec.describe 'GET /oauth/discovery/keys' do
  subject(:keys) do
    get '/oauth/discovery/keys'
    JSON.parse(response.body)['keys']
  end

  let(:public_key) { MyEtm::Auth.signing_key.public_key }

  it 'succeeds' do
    get '/oauth/discovery/keys'
    expect(response).to have_http_status(:ok)
  end

  it 'publishes the current and legacy kid' do
    expect(keys.map { |key| key['kid'] }).to contain_exactly(
      Doorkeeper::OpenidConnect.signing_key.kid,
      JWT::JWK.new(public_key).export[:kid]
    )
  end

  # The two entries are two names for one key, not two keys. If this ever fails, a token signed by
  # MyETM would verify under one kid and not the other.
  it 'publishes the same key material under both kids' do
    expect(keys.map { |key| key.values_at('kty', 'n', 'e') }.uniq.length).to eq(1)
  end

  it 'marks both keys as RS256 signing keys' do
    expect(keys).to all(include('use' => 'sig', 'alg' => 'RS256'))
  end

  # This is the case the legacy entry exists for: a token minted the way doorkeeper_jwt.rb used to
  # name the key must still resolve against the published JWKS.
  it 'lets a token carrying the legacy kid resolve its signing key' do
    legacy_kid = JWT::JWK.new(public_key).export[:kid]
    token = JWT.encode({ sub: '1' }, MyEtm::Auth.signing_key, 'RS256', kid: legacy_kid)
    jwks = JWT::JWK::Set.new('keys' => keys)

    expect { JWT.decode(token, nil, true, algorithms: ['RS256'], jwks: jwks, verify_expiration: false) }
      .not_to raise_error
  end
end
