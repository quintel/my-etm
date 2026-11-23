# frozen_string_literal: true

require "rails_helper"

describe ApiScenario::Interpolate, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:path) { "/api/v3/scenarios/1/interpolate" }

  it "creates a Session interpolated for the end year" do
    allow(client).to receive(:post)
      .with(path, end_year: 2030, keep_compatible: false)
      .and_return(ServicesHelper::StubResponse.new(true, { "id" => 2 }))

    expect(described_class.call(client, 1, 2030).value!).to eq("id" => 2)
  end

  it "tells ETEngine to protect the Session when asked" do
    allow(client).to receive(:post)
      .with(path, end_year: 2030, keep_compatible: true)
      .and_return(ServicesHelper::StubResponse.new(true, { "id" => 2 }))

    expect(described_class.call(client, 1, 2030, keep_compatible: true)).to be_success
  end

  it "names the end year when ETEngine refuses" do
    allow(client).to receive(:post).and_raise(stub_faraday_422([ "must be prior to the original scenario end year" ]))

    expect(described_class.call(client, 1, 2060).failure)
      .to eq(end_year: [ "must be prior to the original scenario end year" ])
  end

  it "fails as upstream when ETEngine cannot be reached" do
    allow(client).to receive(:post).and_raise(Faraday::ConnectionFailed, "down")

    expect(described_class.call(client, 1, 2030).failure)
      .to eq([ :upstream, [ "Failed to interpolate scenario" ] ])
  end
end
