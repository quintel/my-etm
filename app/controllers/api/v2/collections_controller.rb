module Api
  module V2
    class CollectionsController < BaseController
      before_action :require_user, only: %i[index]

      load_and_authorize_resource(class: Collection, only: %i[index show update destroy])

      before_action only: %i[create] do
        authorize!(:create, Collection)
      end

      # GET api/v2/collections
      def index
        render_collection(current_user.collections.kept.order(created_at: :desc), meta: {})
      end

      # GET api/v2/collections/:id
      def show
        render_resource(@collection)
      end

      # POST api/v2/collections
      # TODO: update when changing collection params like scenario_ids and interpolated
      def create
        Api::CreateCollection.new.call(
          user: current_user,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection, status: :created) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # PUT/PATCH api/v2/collections/:id
      # TODO: update when changing collection params like scenario_ids and interpolated
      def update
        Api::UpdateCollection.new.call(
          collection: @collection,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        Api::V2::DestroyCollection.new.call(
          collection: @collection
        ).either(
          ->(collection) { head :no_content },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # PUT api/v2/collections/:id/discard
      def discard;end

      # PUT api/v2/collections/:id/restore
      def restore;end


      private

      # TODO: here we accept both scenario_id and saved_scenario_ids still
      # this should be mitigated to canonical ids only
      # TODO: here we still accept the interpolation parameter, this should
      # be updated
      def collection_params
        params.require(:collection).permit(
          :title, :area_code, :end_year,
          :version, :interpolation, :discarded,
          saved_scenario_ids: [], scenario_ids: []
        )
      end
    end
  end
end
