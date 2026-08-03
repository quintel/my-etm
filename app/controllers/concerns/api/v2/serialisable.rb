module Api
  module V2
    # Serialiser logic shared for API responses
    module Serialisable
      # single
      # returns { data: {}, meta: {} }
      def serialise(resource, meta: {})
        { data: resource.as_json, meta: meta }
      end

      # Public: Serialises a response, based on the resource and result
      #
      def serialise_error(resource, errors)
        serialise(resource, meta: {}).merge!(errors: errors)
      end

      # collection
      # returns { data: [], meta: {} }
      def serialise_collection(resources);end

      # batch update
      # returns { data: [{status}], meta: {}, batch: {succeeded,failed,total} }
      def serialise_batch_update(results_or_resources);end

      # TODO: parse errors?
    end
  end
end
