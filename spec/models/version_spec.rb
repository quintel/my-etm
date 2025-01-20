require 'rails_helper'

describe Version do
  let(:version) { create(:version) }

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
end
