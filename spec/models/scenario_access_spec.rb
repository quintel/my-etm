# frozen_string_literal: true

RSpec.describe ScenarioAccess do
  describe "#grant" do
    it "moves a re-opened Session to the newest end, so eviction takes the least recently opened" do
      access = described_class.new([ [ 1, "read" ], [ 2, "read" ] ]).grant([ [ 1, "read" ] ])

      expect(access.pairs).to eq([ [ 2, "read" ], [ 1, "read" ] ])
    end

    it "keeps the stronger level for a Session named twice in one call" do
      access = described_class.new.grant([ [ 1, "write" ], [ 1, "read" ] ])

      expect(access.pairs).to eq([ [ 1, "write" ] ])
    end
  end
end
