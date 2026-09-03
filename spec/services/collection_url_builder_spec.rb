# frozen_string_literal: true

require 'rails_helper'

RSpec.describe CollectionUrlBuilder do
  describe '.collections_app_url' do
    let(:collection) { create(:collection) }

    it 'is the collection id on the collections host, in the current locale' do
      I18n.with_locale(:nl) do
        expect(described_class.collections_app_url(collection)).to eq(
          "#{collection.version.collections_url}/collections/#{collection.id}?locale=nl"
        )
      end
    end
  end
end
