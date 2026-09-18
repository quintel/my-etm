# frozen_string_literal: true

RSpec.describe EtmApi::Responses::ErrorObject do
  describe ".build" do
    subject(:object) do
      described_class.build(status: :not_found, code: "not_found", detail: "No such collection")
    end

    it "renders the status as the integer the response carries" do
      expect(object[:status]).to eq(404)
    end

    it "keeps the code and detail" do
      expect(object).to include(code: "not_found", detail: "No such collection")
    end

    # Omitted rather than null: a pointer is only meaningful for a member the caller actually sent.
    it "omits source when there is nothing to point at" do
      expect(object).not_to have_key(:source)
    end

    it "keeps source when given one" do
      built = described_class.build(
        status: :unprocessable_content, code: "validation_failed", detail: "is required",
        source: { pointer: "/collection/title" }
      )

      expect(built[:source]).to eq(pointer: "/collection/title")
    end

    # Codes arrive from a service as symbols and are rendered as strings.
    it "renders a symbol code as a string" do
      built = described_class.build(status: :forbidden, code: :forbidden, detail: "Nope")

      expect(built[:code]).to eq("forbidden")
    end

    it "accepts an integer status unchanged" do
      built = described_class.build(status: 418, code: "teapot", detail: "Short and stout")

      expect(built[:status]).to eq(418)
    end
  end
end
