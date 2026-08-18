# frozen_string_literal: true

require "rails_helper"

# Exercises the envelope helpers themselves, on a throwaway controller, so the shapes are asserted
# independently of any resource. Real models are covered by the per-resource request specs, which
# validate every response against lib/api/v2/openapi.yaml.
RSpec.describe Api::V2::BaseController, type: :controller do
  # Stands in for a resource serialiser: the helpers only require something that wraps an object and
  # answers as_json.
  let(:passthrough_serialiser) do
    Class.new do
      def initialize(object)
        @object = object
      end

      def as_json(*)
        @object
      end
    end
  end

  let(:bulk_items) do
    [
      BulkResult::Item.ok(index: 0, identifier: 1, value: { id: 1 }),
      BulkResult::Item.error(index: 1, identifier: 2, code: :not_found, messages: [ "User not found" ]),
      BulkResult::Item.error(
        index: 2, identifier: 2, code: :validation_failed,
        messages: [ "Role is not included in the list", "Email is invalid" ]
      )
    ]
  end

  before do
    stub_const("PassthroughSerialiser", passthrough_serialiser)
    stub_const("BulkFixtureItems", bulk_items)
  end

  controller(described_class) do
    skip_authorization_check

    def resource
      render_resource({ id: 1, name: "Example" }, with: PassthroughSerialiser)
    end

    def collection
      render_collection([ { id: 1 }, { id: 2 } ], with: PassthroughSerialiser)
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

    def bulk
      render_bulk(BulkResult.new(BulkFixtureItems), with: PassthroughSerialiser, pointer: "/items")
    end
  end

  before do
    routes.draw do
      get "resource"   => "api/v2/base#resource"
      get "collection" => "api/v2/base#collection"
      get "accepted"   => "api/v2/base#accepted"
      get "error"      => "api/v2/base#error"
      get "malformed"  => "api/v2/base#malformed"
      get "bulk"       => "api/v2/base#bulk"
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

  describe "GET bulk" do
    before { get :bulk }

    it_behaves_like "a v2 batch response"

    it "renders one item per BulkResult item, addressed by its request index" do
      expect(response.parsed_body["data"]).to eq([
        { "status" => "ok", "id" => 1 },
        {
          "status" => "error", "code" => "not_found", "detail" => "User not found",
          "source" => { "pointer" => "/items/1" }
        },
        {
          "status" => "error", "code" => "validation_failed",
          "detail" => "Role is not included in the list, Email is invalid",
          "source" => { "pointer" => "/items/2" }
        }
      ])
    end

    it "counts every submitted item, so a repeated identifier cannot shrink the total" do
      expect(response.parsed_body.dig("meta", "batch")).to eq(
        "succeeded" => 1, "failed" => 2, "total" => 3
      )
    end

    # The services hand back a bare symbol, so nothing stops one drifting out of the documented set.
    it "only emits codes from the documented ErrorCodes enum" do
      documented = Api::V2::ErrorCodes.constants.map { |name| Api::V2::ErrorCodes.const_get(name) }
      codes = response.parsed_body["data"].filter_map { |item| item["code"] }

      expect(codes).not_to be_empty
      expect(codes).to all(be_in(documented))
    end
  end
end
