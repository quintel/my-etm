# frozen_string_literal: true

module Api
  module V2
    # Explicit attribute allow-list for Collection, so a new column never joins the public contract
    # silently.
    class CollectionSerialiser
      def initialize(collection)
        @collection = collection
      end

      def as_json(*)
        {
          id: collection.id,
          title: collection.title,
          version: collection.version.tag,
          discarded_at: collection.discarded_at,
          created_at: collection.created_at,
          updated_at: collection.updated_at,
          owner: { id: collection.user_id, name: collection.user.name },
          saved_scenario_ids: collection.saved_scenarios.map(&:id),
          collections_app_url: CollectionUrlBuilder.collections_app_url(collection)
        }
      end

      private

      attr_reader :collection
    end
  end
end
