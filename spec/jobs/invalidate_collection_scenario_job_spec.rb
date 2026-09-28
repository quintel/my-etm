# frozen_string_literal: true

require 'rails_helper'

RSpec.describe InvalidateCollectionScenarioJob, type: :job do
  let(:saved_scenario) { create(:saved_scenario) }
  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:path) { "/api/invalidate/scenarios/#{saved_scenario.id}" }

  let(:connection) do
    Faraday.new { |conn| conn.response(:raise_error) && conn.adapter(:test, stubs) }
  end

  let(:decode) do
    lambda do |token|
      JWT.decode(
        token, MyEtm::Auth.signing_key.public_key, true,
        algorithms: [ 'RS256' ], aud: described_class::AUDIENCE, verify_aud: true
      )
    end
  end

  before { allow(Faraday).to receive(:new).and_return(connection) }

  it 'posts the stamp as a signed bearer token' do
    token = nil
    stubs.post(path) { |env| (token = env.request_headers['Authorization'].delete_prefix('Bearer ')) && [ 200, {}, '' ] }

    described_class.perform_now(saved_scenario)
    expect(decode.call(token).first).to include(
      'saved_scenario_id' => saved_scenario.id,
      'stamp' => saved_scenario.updated_at.utc.iso8601(6)
    )
  end

  it 'retries when Collections is unreachable' do
    stubs.post(path) { raise Faraday::ConnectionFailed, 'refused' }

    expect { described_class.perform_now(saved_scenario) }
      .to have_enqueued_job(described_class)
  end

  it 'gives up at once on a 4xx, which a retry cannot fix' do
    stubs.post(path) { [ 404, {}, '' ] }

    expect { described_class.perform_now(saved_scenario) }
      .not_to have_enqueued_job(described_class)
  end
end
