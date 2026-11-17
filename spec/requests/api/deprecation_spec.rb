# frozen_string_literal: true

require "rails_helper"

RSpec.describe "API v1 deprecation", type: :request do
  shared_examples "a deprecated v1 response" do
    it "announces when v1 was deprecated" do
      expect(response.headers["Deprecation"]).to eq("@#{Time.utc(2026, 12, 10).to_i}")
    end

    it "announces when v1 stops answering" do
      expect(response.headers["Sunset"]).to eq("Mon, 01 Mar 2027 00:00:00 GMT")
    end

    it "points at v4 as its successor" do
      expect(response.headers["Link"]).to eq('</api/v4>; rel="successor-version"')
    end
  end

  context "with a successful response" do
    before { get "/api/v1/versions", as: :json }

    it_behaves_like "a deprecated v1 response"
  end

  context "with a refusal" do
    before { get "/api/v1/saved_scenarios/0", as: :json }

    it "is refused" do
      expect(response).not_to be_successful
    end

    it_behaves_like "a deprecated v1 response"
  end

  it "leaves v4 responses alone" do
    get "/api/v4/saved_scenarios", as: :json

    expect(response.headers).not_to include("Deprecation", "Sunset")
  end
end
