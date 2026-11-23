# frozen_string_literal: true

require 'rails_helper'

describe ApiScenario::SetBound, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:user) { create(:user) }
  let(:version) { create(:version) }
  let!(:engine) { create(:oauth_application, uri: version.engine_url, scopes: 'openid public') }
  let(:result) { described_class.call(user, version, [ 1, 2 ], true) }

  before do
    allow(MyEtm::Auth).to receive(:client_for).and_return(client)
    allow(client).to receive(:put)
      .and_return(instance_double(Faraday::Response, body: { 'missing' => [ 2 ] }))
  end

  it 'asks for a token with the engine scopes and the bind scope' do
    result

    expect(MyEtm::Auth).to have_received(:client_for)
      .with(user, engine, scopes: [ 'openid public', 'scenarios:bind' ])
  end

  it 'sends the ids and the flag' do
    result

    expect(client).to have_received(:put)
      .with('/api/v3/scenarios/bind', ids: [ 1, 2 ], bound: true)
  end

  it 'returns the ids ETEngine has no Session for' do
    expect(result.value!).to eq([ 2 ])
  end

  it 'fails upstream when ETEngine fails' do
    allow(client).to receive(:put).and_raise(Faraday::ServerError)

    expect(result.failure).to eq([ :upstream, [ 'Failed to update the session in ETEngine' ] ])
  end

  context 'when ETEngine refuses the Sessions' do
    before do
      allow(client).to receive(:put)
        .and_raise(Faraday::UnprocessableEntityError.new(nil, body: { 'refused' => [ 2 ] }))
    end

    it 'fails with the refused ids' do
      expect(result.failure).to eq([ :refused, [ 2 ] ])
    end
  end

  it 'answers call! with the missing ids' do
    expect(described_class.call!(user, version, [ 1, 2 ], true)).to eq([ 2 ])
  end
end
