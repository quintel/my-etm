# frozen_string_literal: true

require 'rails_helper'

describe SavedScenario::PerformEngineCallbacks, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:result) { described_class.call(client, 1) }

  before do
    allow(client).to receive(:put).with('/api/v3/scenarios/1', { scenario: { keep_compatible: true } })
    allow(client).to receive(:post).with('/api/v3/scenarios/1/version', { description: "" })
  end

  it 'keeps the scenario compatible' do
    result

    expect(client).to have_received(:put).with('/api/v3/scenarios/1', { scenario: { keep_compatible: true } })
  end

  it 'tags the scenario version' do
    result

    expect(client).to have_received(:post).with('/api/v3/scenarios/1/version', { description: "" })
  end

  it 'succeeds with the scenario ID' do
    expect(result.value!).to eq(1)
  end

  it 'makes no other call by default' do
    result

    expect(client).to have_received(:put).once
  end

  context 'when asked to match the privacy' do
    let(:saved_scenario) { instance_double(SavedScenario, private: true) }
    let(:result) do
      described_class.call(client, 1, operations: [ :set_privacy ], saved_scenario:)
    end

    before do
      allow(client).to receive(:put).with('/api/v3/scenarios/1', { scenario: { private: true } })
    end

    it 'sends the saved scenario privacy' do
      result

      expect(client).to have_received(:put).with('/api/v3/scenarios/1', { scenario: { private: true } })
    end

    it 'skips the operations it was not asked for' do
      result

      expect(client).not_to have_received(:post)
    end
  end

  it 'refuses an unknown operation, such as the retired role sync' do
    expect { described_class.call(client, 1, operations: [ :set_roles ]) }
      .to raise_error(ArgumentError, /set_roles/)
  end

  context 'when ETEngine refuses the version tag' do
    before do
      allow(client).to receive(:post).and_raise(Faraday::ResourceNotFound.new(nil))
    end

    it 'fails as upstream' do
      expect(result.failure).to eq([ :upstream, [ 'Scenario tag not found' ] ])
    end

    it 'still keeps the scenario compatible' do
      result

      expect(client).to have_received(:put)
    end
  end

  context 'when ETEngine refuses to keep the scenario compatible' do
    before do
      allow(Sentry).to receive(:capture_exception)
      allow(client).to receive(:put).and_raise(Faraday::ForbiddenError.new(nil))
    end

    it 'fails as upstream, even though ETEngine gave no message' do
      expect(result.failure).to eq([ :upstream, [ 'ETEngine refused the request' ] ])
    end
  end
end
