# frozen_string_literal: true

RSpec.describe EtmApi::Responses::Validation do
  describe ".failures" do
    it "reports one pair per message" do
      expect(described_class.failures(title: [ "is required", "is too short" ]))
        .to eq([ [ [ :title ], "is required" ], [ [ :title ], "is too short" ] ])
    end

    # A contract reports a failing collection member as { key => { index => [messages] } }, so the
    # index has to survive into the path for the pointer to address the right position.
    it "walks into a nested index" do
      expect(described_class.failures(saved_scenario_ids: { 2 => [ "not found" ] }))
        .to eq([ [ [ :saved_scenario_ids, 2 ], "not found" ] ])
    end

    it "walks arbitrarily deep" do
      expect(described_class.failures(a: { b: { c: [ "deep" ] } }))
        .to eq([ [ %i[a b c], "deep" ] ])
    end

    it "reports every key" do
      expect(described_class.failures(title: [ "is required" ], area_code: [ "is unknown" ]))
        .to eq([ [ [ :title ], "is required" ], [ [ :area_code ], "is unknown" ] ])
    end

    it "accepts a bare message rather than a list" do
      expect(described_class.failures(title: "is required")).to eq([ [ [ :title ], "is required" ] ])
    end

    it "states a non-string message as a string" do
      expect(described_class.failures(title: [ :blank ])).to eq([ [ [ :title ], "blank" ] ])
    end

    it "reports nothing for no failures" do
      expect(described_class.failures({})).to eq([])
    end
  end

  describe ".unspecified_failure" do
    subject(:object) { described_class.unspecified_failure }

    # `errors` must hold at least one object, and a failure can arrive carrying none.
    it "is a complete error object" do
      expect(object).to eq(
        status: 422, code: EtmApi::Errors::Codes::VALIDATION_FAILED,
        detail: "The request could not be applied"
      )
    end

    it "points at nothing, since no member is known to have failed" do
      expect(object).not_to have_key(:source)
    end
  end
end
