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

    def strict
      render_ok(accepted: resource_params(:title, tags: []).to_h)
    end

    def versioned
      return if reject_unknown_version(params.require(:thing)[:version])

      render_ok
    end

    def capped
      return if reject_oversized(:tags, params.require(:thing)[:tags])

      render_ok
    end

    private

    def request_members
      %i[title tags version]
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
      post "strict"    => "api/v2/base#strict"
      post "versioned" => "api/v2/base#versioned"
      post "capped"    => "api/v2/base#capped"
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

  describe "POST strict" do
    before { self.class.controller_class.resource_param_key = :thing }

    it "accepts a body of nothing but accepted members" do
      post :strict, params: { thing: { title: "Example", tags: [ "a" ] } }, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.dig("data", "accepted")).to eq("title" => "Example", "tags" => [ "a" ])
    end

    it "refuses a member the resource does not have, naming it" do
      post :strict, params: { thing: { title: "Example", random_thing: 1 } }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["errors"].sole).to eq(
        "status" => 400, "code" => "param_invalid",
        "detail" => "is not a member of this resource",
        "source" => { "pointer" => "/thing/random_thing" }
      )
    end

    it "distinguishes a member the resource has but this action will not set" do
      post :strict, params: { thing: { title: "Example", version: "latest" } }, as: :json

      expect(response.parsed_body["errors"].sole).to include(
        "code" => "param_invalid",
        "detail" => "cannot be set by this action",
        "source" => { "pointer" => "/thing/version" }
      )
    end

    it "reports every refused member, one error object each" do
      post :strict, params: { thing: { version: "latest", random_thing: 1 } }, as: :json

      expect(response.parsed_body["errors"].map { |error| error.dig("source", "pointer") })
        .to contain_exactly("/thing/version", "/thing/random_thing")
    end

    it "refuses a list member that did not arrive as a list, rather than dropping it" do
      post :strict, params: { thing: { title: "Example", tags: "a" } }, as: :json

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "param_invalid",
        "detail" => "tags must be an array",
        "source" => { "pointer" => "/thing/tags" }
      )
    end

    it "leaves an absent list member absent rather than refusing it" do
      post :strict, params: { thing: { title: "Example" } }, as: :json

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST capped" do
    before { self.class.controller_class.resource_param_key = :thing }

    it "accepts a request at the limit" do
      post :capped, params: { thing: { tags: [ "a" ] * Api::V2::BaseController::BATCH_LIMIT } }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "refuses one item over the limit, as one error rather than one per item" do
      over = Api::V2::BaseController::BATCH_LIMIT + 1

      post :capped, params: { thing: { tags: [ "a" ] * over } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "validation_failed",
        "detail" => "size cannot be greater than 100",
        "source" => { "pointer" => "/thing/tags" }
      )
    end
  end

  # Both Collection#version= and SavedScenario::Create silently fall back to the default tag.
  describe "POST versioned" do
    before { self.class.controller_class.resource_param_key = :thing }

    it "accepts a tag that resolves" do
      post :versioned, params: { thing: { version: Version.default.tag } }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "accepts an absent tag, leaving the default to the service" do
      post :versioned, params: { thing: { title: "Example" } }, as: :json

      expect(response).to have_http_status(:ok)
    end

    it "refuses a tag that does not resolve, rather than quietly substituting the default" do
      post :versioned, params: { thing: { version: "not-a-version" } }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "validation_failed",
        "detail" => "is not a known version",
        "source" => { "pointer" => "/thing/version" }
      )
    end
  end
end
