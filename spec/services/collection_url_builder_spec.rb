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

    context 'when the collection belongs to the frozen 2025.01 version' do
      let(:version) { create(:version, tag: '2025.01') }

      let(:collection) do
        create(:collection, version: version, title: 'My collection', scenarios_count: 2)
      end

      it 'is the scenario ids and the title, the only shape that version of the app reads' do
        I18n.with_locale(:en) do
          expect(described_class.collections_app_url(collection)).to eq(
            "#{version.collections_url}/#{collection.latest_scenario_ids.join(',')}" \
            "?locale=en&title=My%20collection"
          )
        end
      end

      it 'lists the scenario ids of a transition path which holds only saved scenarios' do
        collection.scenarios.destroy_all
        owner = collection.user

        collection.saved_scenarios = [
          create(:saved_scenario, user: owner, version: version, end_year: 2030, scenario_id: 11),
          create(:saved_scenario, user: owner, version: version, end_year: 2050, scenario_id: 22)
        ]

        I18n.with_locale(:en) do
          expect(described_class.collections_app_url(collection.reload))
            .to include("#{version.collections_url}/11,22?")
        end
      end
    end
  end
end
