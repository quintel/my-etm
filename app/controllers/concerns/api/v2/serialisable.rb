module Api
  module V2
    # Serialiser logic shared for API responses
    module Serialisable
      # single
      # returns { data: {}, meta: {} }
      def serialise(resource, meta: {})
        { data: resource.to_json, meta: meta }
      end

      # collection
      # returns { data: [], meta: {} }
      def serialise_collection(resources);end

      # batch update
      # returns { data: [{status}], meta: {}, batch: {succeeded,failed,total} }
      def serialise_batch_update(results_or_resources);end

      # serialise error for resource
    end
  end
end
