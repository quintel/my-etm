# frozen_string_literal: true

RSpec.describe EtmApi::Responses do
  describe ".data" do
    it "wraps the payload with an empty meta by default" do
      expect(described_class.data({ id: 1 })).to eq(data: { id: 1 }, meta: {})
    end

    it "keeps the given meta" do
      expect(described_class.data([], meta: { total: 0 })).to eq(data: [], meta: { total: 0 })
    end

    # The resource and collection kinds share a shape; only the type of `data` differs.
    it "does not care whether the payload is an object or a list" do
      expect(described_class.data([ { id: 1 } ])).to eq(data: [ { id: 1 } ], meta: {})
    end
  end

  describe ".ok" do
    it "states the status" do
      expect(described_class.ok).to eq(data: { status: "ok" }, meta: {})
    end

    it "merges anything extra alongside it" do
      expect(described_class.ok(deleted: 3)).to eq(data: { status: "ok", deleted: 3 }, meta: {})
    end
  end

  describe ".errors" do
    it "wraps the objects" do
      expect(described_class.errors([ { status: 404 } ])).to eq(errors: [ { status: 404 } ])
    end
  end

  describe ".batch" do
    let(:items) do
      [
        described_class.batch_ok({ id: 1 }),
        described_class.batch_error(code: "not_found", detail: "Gone", pointer: "/ids/1"),
        described_class.batch_ok({ id: 3 })
      ]
    end

    it "returns one item per item given" do
      expect(described_class.batch(items)[:data].size).to eq(3)
    end

    it "counts the successes and failures" do
      expect(described_class.batch(items)[:meta][:batch])
        .to eq(succeeded: 2, failed: 1, total: 3)
    end

    # Always reports every submitted item, so a repeated identifier cannot shrink the total.
    it "counts a repeated item twice" do
      repeated = [ described_class.batch_ok({ id: 1 }), described_class.batch_ok({ id: 1 }) ]

      expect(described_class.batch(repeated)[:meta][:batch])
        .to eq(succeeded: 2, failed: 0, total: 2)
    end

    it "reports zero of everything for no items" do
      expect(described_class.batch([])).to eq(data: [], meta: { batch: { succeeded: 0, failed: 0, total: 0 } })
    end
  end

  describe ".batch_ok" do
    it "nests the payload under data" do
      expect(described_class.batch_ok({ id: 1 })).to eq(status: "ok", data: { id: 1 })
    end
  end

  describe ".batch_error" do
    it "carries the code, detail and pointer" do
      expect(described_class.batch_error(code: "not_found", detail: "Gone", pointer: "/ids/0"))
        .to eq(status: "error", code: "not_found", detail: "Gone", source: { pointer: "/ids/0" })
    end
  end

  describe ".item_code" do
    it "renders a documented code" do
      expect(described_class.item_code(:not_found)).to eq(EtmApi::Errors::Codes::NOT_FOUND)
    end

    # nil rather than a fallback, leaving the caller to decide how to report it.
    it "is nil for a code outside the documented set" do
      expect(described_class.item_code(:teapot)).to be_nil
    end
  end

  describe "ITEM_CODES" do
    it "names only documented codes" do
      documented = EtmApi::Errors::Codes.constants.map { |name| EtmApi::Errors::Codes.const_get(name) }

      expect(described_class::ITEM_CODES.values).to all(be_in(documented))
    end
  end
end
