require 'rails_helper'

describe Version do
  let(:version) { create(:version) }

  describe "#label" do
    it "is the tag of a version named by its year" do
      expect(described_class.new(tag: "2027").label).to eq("2027")
    end

    it "leaves out the .01 of 2025.01" do
      expect(described_class.new(tag: "2025.01").label).to eq("2025")
    end
  end

  describe "#released_on" do
    it "is the release date in the settings for the default version" do
      expect(described_class.default.released_on).to eq(Date.iso8601(Settings.release_date))
    end

    it "is the date a stable version was given" do
      expect(create(:version, released_on: Date.new(2027, 1, 12)).released_on).to eq(Date.new(2027, 1, 12))
    end

    it "is required for a stable version" do
      expect(build(:version, released_on: nil)).not_to be_valid
    end

    it "is not required for the default version" do
      version = described_class.default
      version.valid?

      expect(version.errors[:released_on]).to be_empty
    end
  end

  describe "#default" do
    context 'when there was no default set' do
      before { Version.default.destroy }

      it 'creates a default' do
        expect { Version.default }.to change { Version.all.count }.by(1)
      end
    end

    context 'when there was a default set' do
      it 'does not create a new version' do
        expect { Version.default }.not_to change { Version.all.count }
      end

      it 'returns the default' do
        expect(Version.default.default).to be_truthy
      end
    end

    context 'when trying to create a new default when one was already there' do
      it 'does not create a new record' do
        expect(Version.new(default: true, tag: 'new_default', url_prefix: 'x')).to_not(be_valid)
      end
    end
  end

  describe "#deletable?" do
    it "is true for a version nothing belongs to" do
      expect(version).to be_deletable
    end

    it "is false for the default version" do
      expect(described_class.default).not_to be_deletable
    end

    it "is false when it has saved scenarios" do
      create(:saved_scenario, version: version)

      expect(version).not_to be_deletable
    end

    it "is false when it has collections" do
      create(:collection, version: version)

      expect(version).not_to be_deletable
    end
  end
end
