# frozen_string_literal: true

RSpec.describe MyEtm::TokenPayload do
  include ActiveSupport::Testing::TimeHelpers

  let(:user) { create(:user) }
  let(:stable) { Version.find_by(tag: "stable.01") }

  def build(**options)
    described_class.new(user:, scopes: "openid scenarios:read", **options).to_h
  end

  describe "the audience" do
    it "is the application's Version and MyETM for an application token" do
      application = create(:oauth_application, version: stable)

      expect(build(application:)[:aud]).to eq(stable.urls + [ Settings.auth.issuer ])
    end

    it "is the Version's engine alone for a relayed call" do
      expect(build(version: stable)[:aud]).to eq([ stable.engine_url ])
    end

    it "is every app and MyETM for the session cookie" do
      payload = build(scopes: "openid roles")

      expect(payload[:aud]).to eq(Version.all.flat_map(&:urls).uniq + [ Settings.auth.issuer ])
    end

    it "is every engine, and not MyETM, for a PAT" do
      expect(build[:aud]).to eq(Version.all.map(&:engine_url))
    end
  end

  it "identifies the user" do
    expect(build).to include(sub: user.id, user: user.as_json(only: %i[id admin email name]))
  end

  it "carries the scopes as given" do
    expect(build[:scopes]).to eq("openid scenarios:read")
  end

  it "expires after expires_in" do
    freeze_time do
      expect(build(expires_in: 120)[:exp]).to eq(Time.now.to_i + 120)
    end
  end

  it "does not expire without expires_in" do
    expect(build).not_to have_key(:exp)
  end

  it "groups a grant by Version and level" do
    payload = build(scenario_access: [ [ "latest", 1, "write" ] ])

    expect(payload[ScenarioAccess::CLAIM]).to eq("latest" => { "write" => [ 1 ] })
  end

  it "has no grant claim without one" do
    expect(build).not_to have_key(ScenarioAccess::CLAIM)
  end
end
