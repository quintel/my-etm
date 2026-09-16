# frozen_string_literal: true

# Each error carries the member it is about, so a controller can build a pointer from it rather
# than parsing the message back out.
RSpec.describe EtmApi::Errors do
  describe EtmApi::Errors::InvalidParam do
    subject(:error) { described_class.new("/collection/title", "title must be a single value") }

    it "keeps the pointer" do
      expect(error.pointer).to eq("/collection/title")
    end

    it "uses the given message" do
      expect(error.message).to eq("title must be a single value")
    end
  end

  describe EtmApi::Errors::OversizedMember do
    subject(:error) { described_class.new(:saved_scenario_ids) }

    it "keeps the member" do
      expect(error.member).to eq(:saved_scenario_ids)
    end

    it "names the member in the message" do
      expect(error.message).to eq("oversized member: saved_scenario_ids")
    end
  end

  describe EtmApi::Errors::UnacceptedMembers do
    subject(:error) { described_class.new(%i[colour shape]) }

    it "keeps every member" do
      expect(error.members).to eq(%i[colour shape])
    end

    it "lists them all in the message" do
      expect(error.message).to eq("unaccepted members: colour, shape")
    end
  end

  describe EtmApi::Errors::UnknownVersion do
    subject(:error) { described_class.new(:version) }

    it "keeps the member" do
      expect(error.member).to eq(:version)
    end

    it "names the member in the message" do
      expect(error.message).to eq("unknown version: version")
    end
  end

  describe EtmApi::Errors::Codes do
    it "gives every code a distinct value" do
      codes = described_class.constants.map { |name| described_class.const_get(name) }

      expect(codes.uniq.size).to eq(codes.size)
    end

    it "states every code as a string, since it is rendered verbatim" do
      expect(described_class.constants).to all(satisfy { |n| described_class.const_get(n).is_a?(String) })
    end
  end
end
