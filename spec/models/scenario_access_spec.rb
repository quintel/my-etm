# frozen_string_literal: true

RSpec.describe ScenarioAccess do
  def entry(tag, session_id, level) = described_class::Entry.new(tag:, session_id:, level:)

  describe ".new" do
    it "casts each entry's tag, Session ID and level" do
      entry = described_class.new([ [ :latest, "2", :read ] ]).entries.first

      expect(entry).to have_attributes(tag: "latest", session_id: 2, level: "read")
    end

    it "drops entries stored without a Version tag, keeping the rest" do
      access = described_class.new([ [ 1, "write" ], [ "latest", 2, "read" ] ])

      expect(access.entries.map(&:to_a)).to eq([ [ "latest", 2, "read" ] ])
    end
  end

  describe "#grant" do
    it "moves a re-opened Session to the newest end, so eviction takes the least recently opened" do
      access = described_class.new([ [ "latest", 1, "read" ], [ "latest", 2, "read" ] ])
        .grant([ entry("latest", 1, "read") ])

      expect(access.entries.map(&:to_a)).to eq([ [ "latest", 2, "read" ], [ "latest", 1, "read" ] ])
    end

    it "keeps the stronger level for a Session named twice in one call" do
      access = described_class.new.grant([ entry("latest", 1, "write"), entry("latest", 1, "read") ])

      expect(access.entries.map(&:to_a)).to eq([ [ "latest", 1, "write" ] ])
    end

    it "holds the same Session ID on two Versions apart" do
      access = described_class.new([ [ "2025.01", 1, "write" ] ]).grant([ entry("latest", 1, "read") ])

      expect(access.entries.map(&:to_a)).to eq([ [ "2025.01", 1, "write" ], [ "latest", 1, "read" ] ])
    end

    it "refuses a plain array, which only storage holds" do
      expect { described_class.new.grant([ [ "latest", 1, "read" ] ]) }.to raise_error(NoMethodError)
    end
  end

  describe "#entries" do
    it "serialises as the [version_tag, session_id, level] arrays it is stored as" do
      access = described_class.new([ [ "latest", 1, "write" ] ])

      expect(JSON.parse(access.entries.to_json)).to eq([ [ "latest", 1, "write" ] ])
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
