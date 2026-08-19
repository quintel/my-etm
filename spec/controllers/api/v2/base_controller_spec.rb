# frozen_string_literal: true

require "rails_helper"

# Exercises the envelope helpers themselves, on a throwaway controller, so the shapes are asserted
# independently of any resource. Real models are covered by the per-resource request specs, which
# validate every response against the kinds in spec/support/api/v2/envelope.rb.
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

    def ok
      render_ok(job_id: "abc-123")
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

    def invalid
      render_validation_errors(title: [ "is too short" ], secret: [ "is not yours to set" ])
    end

    private

    def request_members
      %i[title]
    end
  end

  before do
    routes.draw do
      get "resource"   => "api/v2/base#resource"
      get "collection" => "api/v2/base#collection"
      get "ok"         => "api/v2/base#ok"
      get "error"      => "api/v2/base#error"
      get "malformed"  => "api/v2/base#malformed"
      get "bulk"       => "api/v2/base#bulk"
      get "invalid"    => "api/v2/base#invalid"
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

  describe "GET ok" do
    before { get :ok }

    it_behaves_like "a v2 ok response"
  end

  describe "GET error" do
    before { get :error }

    it_behaves_like "a v2 error response"
  end

  it "matches the closed set of kinds without one being named" do
    get :resource

    expect(response.parsed_body).to validate_against_the_v2_envelope
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
    it "only emits codes an item is allowed to carry" do
      codes = response.parsed_body["data"].filter_map { |item| item["code"] }

      expect(codes).not_to be_empty
      expect(codes).to all(be_in(Api::V2::Responses::ITEM_CODES.values))
    end
  end

  describe "an item code outside the documented set" do
    let(:bulk_items) do
      [ BulkResult::Item.error(index: 0, identifier: 1, code: :teapot, messages: [ "nope" ]) ]
    end

    it "answers internal_error rather than inventing a code, and reports it" do
      expect(Sentry).to receive(:capture_message).with(/Undocumented Api::V2 batch item code: :teapot/)

      get :bulk

      expect(response.parsed_body.dig("data", 0, "code")).to eq("internal_error")
      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
    end
  end

  # A pointer is only meaningful if it names something the caller actually sent, so a failure on
  # anything outside the request's own members carries no source.
  describe "GET invalid" do
    before { get :invalid }

    it_behaves_like "a v2 error response"

    it "points a failing request member at itself" do
      titles = response.parsed_body["errors"].select { |error| error["detail"] == "is too short" }

      expect(titles.sole["source"]).to eq("pointer" => "/title")
    end

    it "omits the source when the failing key is not a request member" do
      others = response.parsed_body["errors"].reject { |error| error["detail"] == "is too short" }

      expect(others.sole).not_to have_key("source")
    end
  end
end
