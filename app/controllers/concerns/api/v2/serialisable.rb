module Api
  module V2
    # Serialiser logic shared for API responses
    module Serialisable
      # single
      # returns { data: {}, meta: {} }
      def serialise(resource, meta: {})
        { data: resource.as_json, meta: meta }
      end

      # Public: Serialises a response, based on the resource and errors
      #
      # def serialise_error(resource, errors, status: :failed)
      #   serialise(resource, meta: {}).merge!(errors: error_objects(errors))
      # end

      # Public: Serialises a collection of resources
      def serialise_collection(resources, meta: {})
        { data: resources.map(&:as_json), meta: }
      end

      # batch update
      # returns { data: [{status}], meta: {}, batch: {succeeded,failed,total} }
      def serialise_batch_update(results_or_resources);end
    end
  end
end
