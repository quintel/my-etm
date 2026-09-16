# frozen_string_literal: true

# Bodies here are string-keyed because the envelope validates a *parsed response*, not the
# symbol-keyed payload a builder returns. The round-trip below is what ties the two together.
RSpec.describe EtmApi::Envelope do
  def violations(body, kind)
    described_class.violations(body, kind)
  end

  describe ".violations" do
    context "with a kind outside the closed set" do
      it "names the kinds that exist" do
        expect(violations({}, :teapot)).to contain_exactly(a_string_including("is not a response kind"))
      end
    end

    context "with something that is not an object" do
      it "says so" do
        expect(violations([], :resource)).to contain_exactly("expected a JSON object, got Array")
      end
    end

    describe "the resource kind" do
      it "accepts data and meta" do
        expect(violations({ "data" => { "id" => 1 }, "meta" => {} }, :resource)).to be_empty
      end

      it "requires meta" do
        expect(violations({ "data" => {} }, :resource)).to include("is missing meta")
      end

      it "refuses a key it does not name" do
        expect(violations({ "data" => {}, "meta" => {}, "extra" => 1 }, :resource))
          .to include("has unexpected extra")
      end

      it "requires data to be an object" do
        expect(violations({ "data" => [], "meta" => {} }, :resource)).to include("data must be an object")
      end
    end

    describe "the collection kind" do
      it "accepts a list of objects" do
        expect(violations({ "data" => [ { "id" => 1 } ], "meta" => {} }, :collection)).to be_empty
      end

      it "accepts an empty list" do
        expect(violations({ "data" => [], "meta" => {} }, :collection)).to be_empty
      end

      it "requires data to be a list" do
        expect(violations({ "data" => {}, "meta" => {} }, :collection)).to include("data must be an array")
      end

      # Addressed by index, so a caller can tell which member of the list is wrong.
      it "names the position of a member that is not an object" do
        expect(violations({ "data" => [ "nope" ], "meta" => {} }, :collection))
          .to include("data/0 must be an object")
      end
    end

    describe "the ok kind" do
      it "accepts a status of ok" do
        expect(violations({ "data" => { "status" => "ok" }, "meta" => {} }, :ok)).to be_empty
      end

      it "accepts anything extra alongside the status" do
        expect(violations({ "data" => { "status" => "ok", "deleted" => 3 }, "meta" => {} }, :ok)).to be_empty
      end

      it "refuses any other status" do
        expect(violations({ "data" => { "status" => "error" }, "meta" => {} }, :ok))
          .to include('data/status must be "ok"')
      end
    end

    describe "the no_content kind" do
      it "accepts no body at all" do
        expect(violations(nil, :no_content)).to be_empty
      end

      it "accepts an empty body" do
        expect(violations("", :no_content)).to be_empty
      end

      it "refuses a body" do
        expect(violations({ "data" => {} }, :no_content))
          .to contain_exactly("a no_content response must carry no body")
      end
    end

    describe "the batch kind" do
      let(:ok_item) { { "status" => "ok", "data" => { "id" => 1 } } }
      let(:error_item) do
        { "status" => "error", "code" => "not_found", "detail" => "Gone",
          "source" => { "pointer" => "/ids/1" } }
      end
      let(:counters) { { "succeeded" => 1, "failed" => 1, "total" => 2 } }

      it "accepts a mix of ok and error items" do
        expect(violations({ "data" => [ ok_item, error_item ], "meta" => { "batch" => counters } }, :batch))
          .to be_empty
      end

      it "requires the batch counters" do
        expect(violations({ "data" => [], "meta" => {} }, :batch))
          .to contain_exactly("meta must carry a batch object")
      end

      it "requires every counter" do
        expect(violations({ "data" => [], "meta" => { "batch" => { "succeeded" => 0 } } }, :batch))
          .to include("meta/batch is missing failed, total")
      end

      it "refuses a negative counter" do
        negative = { "succeeded" => -1, "failed" => 0, "total" => 0 }

        expect(violations({ "data" => [], "meta" => { "batch" => negative } }, :batch))
          .to include("meta/batch/succeeded must be a non-negative integer")
      end

      it "refuses an item status it does not name" do
        expect(violations({ "data" => [ { "status" => "maybe" } ], "meta" => { "batch" => counters } }, :batch))
          .to include('data/0/status must be "ok" or "error"')
      end

      it "refuses an item code outside the documented set" do
        item = error_item.merge("code" => "teapot")

        expect(violations({ "data" => [ item ], "meta" => { "batch" => counters } }, :batch))
          .to include(a_string_including("data/0/code must be one of"))
      end

      # Unlike a top-level error object, a batch item must say which position failed: the item
      # itself carries no other way to tell.
      it "requires a source on an error item" do
        item = error_item.except("source")

        expect(violations({ "data" => [ item ], "meta" => { "batch" => counters } }, :batch))
          .to include("data/0/source is required")
      end
    end

    describe "the error kind" do
      let(:object) { { "status" => 422, "code" => "validation_failed", "detail" => "is required" } }

      it "accepts an error object without a source" do
        expect(violations({ "errors" => [ object ] }, :error)).to be_empty
      end

      it "accepts one with a source" do
        with_source = object.merge("source" => { "pointer" => "/collection/title" })

        expect(violations({ "errors" => [ with_source ] }, :error)).to be_empty
      end

      it "requires at least one object" do
        expect(violations({ "errors" => [] }, :error)).to include("errors must hold at least 1")
      end

      it "refuses data alongside errors" do
        expect(violations({ "errors" => [ object ], "data" => {} }, :error))
          .to include("has unexpected data")
      end

      it "requires the status to be an integer, not the symbol a builder was given" do
        expect(violations({ "errors" => [ object.merge("status" => "422") ] }, :error))
          .to include("errors/0/status must be an integer")
      end

      it "requires a pointer to be a JSON Pointer" do
        with_source = object.merge("source" => { "pointer" => "collection/title" })

        expect(violations({ "errors" => [ with_source ] }, :error))
          .to include("errors/0/source/pointer must start with /")
      end
    end
  end

  describe "ITEM_CODES" do
    # Validated against the same map the batch builder uses, so the two cannot disagree.
    it "is exactly what the batch builder can emit" do
      expect(described_class::ITEM_CODES).to eq(EtmApi::Responses::ITEM_CODES.values)
    end
  end

  # The builders emit symbol keys; the envelope reads string keys. They meet only after the
  # response has been serialised, so that is how they are checked against each other.
  describe "agreement with the builders" do
    def rendered(payload)
      JSON.parse(payload.to_json)
    end

    it "accepts what data builds, as a resource" do
      expect(violations(rendered(EtmApi::Responses.data({ id: 1 })), :resource)).to be_empty
    end

    it "accepts what data builds, as a collection" do
      expect(violations(rendered(EtmApi::Responses.data([ { id: 1 } ])), :collection)).to be_empty
    end

    it "accepts what ok builds" do
      expect(violations(rendered(EtmApi::Responses.ok(deleted: 3)), :ok)).to be_empty
    end

    it "accepts what batch builds" do
      items = [
        EtmApi::Responses.batch_ok({ id: 1 }),
        EtmApi::Responses.batch_error(
          code: EtmApi::Responses.item_code(:not_found), detail: "Gone", pointer: "/ids/1"
        )
      ]

      expect(violations(rendered(EtmApi::Responses.batch(items)), :batch)).to be_empty
    end

    it "accepts what errors builds from an error object" do
      object = EtmApi::Responses::ErrorObject.build(
        status: :unprocessable_content, code: EtmApi::Errors::Codes::VALIDATION_FAILED,
        detail: "is required", source: { pointer: "/collection/title" }
      )

      expect(violations(rendered(EtmApi::Responses.errors([ object ])), :error)).to be_empty
    end

    it "accepts the unspecified validation failure" do
      object = EtmApi::Responses::Validation.unspecified_failure

      expect(violations(rendered(EtmApi::Responses.errors([ object ])), :error)).to be_empty
    end
  end
end
