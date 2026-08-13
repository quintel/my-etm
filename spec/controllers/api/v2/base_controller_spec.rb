# frozen_string_literal: true

require "rails_helper"

RSpec.describe Api::V2::BaseController, type: :controller do
  controller(described_class) do
    skip_authorization_check

    def resource
      render_resource({ id: 1, name: "Example" })
    end

    def collection
      render_collection([ { id: 1 }, { id: 2 } ], meta: {})
    end

    def batch
      render_batch([
        { status: "ok", id: 1 },
        { status: "error", code: "not_found", detail: "Saved scenario user not found" }
      ])
    end

    def accepted
      render_accepted(job_id: "abc-123")
    end

    def error
      render_error(status: :forbidden, code: "forbidden", detail: "Scenario does not belong to you")
    end

    def malformed
      render json: { data: {}, errors: [] }
    end
  end

  before do
    routes.draw do
      get "resource"   => "api/v2/base#resource"
      get "collection" => "api/v2/base#collection"
      get "batch"      => "api/v2/base#batch"
      get "accepted"   => "api/v2/base#accepted"
      get "error"      => "api/v2/base#error"
      get "malformed"  => "api/v2/base#malformed"
    end
  end

  describe "GET resource" do
    before { get :resource }

    it_behaves_like "a v2 resource response"

    it "carries the rendered payload" do
      expect(response.parsed_body).to eq("data" => { "id" => 1, "name" => "Example" }, "meta" => {})
    end
  end

  describe "GET collection" do
    before { get :collection }

    it_behaves_like "a v2 collection response"
  end

  describe "GET batch" do
    before { get :batch }

    it_behaves_like "a v2 batch response"

    it "reports per-item counts in meta.batch" do
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
    end
  end

  describe "GET accepted" do
    before { get :accepted }

    it_behaves_like "a v2 accepted response"
  end

  describe "GET error" do
    before { get :error }

    it_behaves_like "a v2 error response"
  end

  it "fails the conformance matcher for a payload carrying both data and errors" do
    get :malformed

    expect(response.parsed_body).not_to validate_against_the_v2_envelope
  end
end
