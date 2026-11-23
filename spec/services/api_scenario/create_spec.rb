# frozen_string_literal: true

require "rails_helper"

describe ApiScenario::Create, type: :service do
  let(:client) { instance_double(Faraday::Connection) }
  let(:session) { { "id" => 2, "area_code" => "nl2023", "end_year" => 2050 } }

  it "creates a fresh Session from an area and end year" do
    allow(client).to receive(:post)
      .with("/api/v3/scenarios", scenario: { area_code: "nl2023", end_year: 2050 })
      .and_return(ServicesHelper::StubResponse.new(true, session))

    expect(described_class.call(client, { area_code: "nl2023", end_year: 2050 }).value!).to eq(session)
  end

  it "clones a Session" do
    allow(client).to receive(:post)
      .with("/api/v3/scenarios", scenario: { scenario_id: 1 })
      .and_return(ServicesHelper::StubResponse.new(true, session))

    expect(described_class.call(client, { scenario_id: 1 }).value!).to eq(session)
  end

  it "keeps ETEngine's errors per attribute when it refuses a create" do
    allow(client).to receive(:post).and_raise(stub_faraday_422("area_code" => [ "is unknown" ]))

    expect(described_class.call(client, { area_code: "xx", end_year: 2050 }).failure)
      .to eq("area_code" => [ "is unknown" ])
  end

  it "fails as upstream when ETEngine cannot be reached" do
    allow(client).to receive(:post).and_raise(Faraday::ConnectionFailed, "down")

    expect(described_class.call(client, { scenario_id: 1 }).failure)
      .to eq([ :upstream, [ "Failed to create the session in ETEngine" ] ])
  end
end
