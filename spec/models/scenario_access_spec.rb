# frozen_string_literal: true

RSpec.describe ScenarioAccess do
  describe ".new" do
    it "drops entries stored without a Version tag, keeping the rest" do
      access = described_class.new([ [ 1, "write" ], [ "latest", 2, "read" ] ])

      expect(access.entries).to eq([ [ "latest", 2, "read" ] ])
    end
  end

  describe "#grant" do
    it "moves a re-opened Session to the newest end, so eviction takes the least recently opened" do
      access = described_class.new([ [ "latest", 1, "read" ], [ "latest", 2, "read" ] ])
        .grant([ [ "latest", 1, "read" ] ])

      expect(access.entries).to eq([ [ "latest", 2, "read" ], [ "latest", 1, "read" ] ])
    end

    it "keeps the stronger level for a Session named twice in one call" do
      access = described_class.new.grant([ [ "latest", 1, "write" ], [ "latest", 1, "read" ] ])

      expect(access.entries).to eq([ [ "latest", 1, "write" ] ])
    end

    it "holds the same Session ID on two Versions apart" do
      access = described_class.new([ [ "2025.01", 1, "write" ] ]).grant([ [ "latest", 1, "read" ] ])

      expect(access.entries).to eq([ [ "2025.01", 1, "write" ], [ "latest", 1, "read" ] ])
    end
  end

  describe "#as_claim" do
    it "groups Session IDs by Version, then level, leaving out empty levels" do
      access = described_class.new(
        [ [ "latest", 1, "write" ], [ "latest", 2, "read" ], [ "2025.01", 1, "write" ] ]
      )

      expect(access.as_claim).to eq(
        "latest" => { "write" => [ 1 ], "read" => [ 2 ] }, "2025.01" => { "write" => [ 1 ] }
      )
    end
  end
end
