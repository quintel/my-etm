module Api
  module V2
    class CollectionsController < BaseController
      include Api::V2::Serialisable

      # TODO: @Louis hook in here for resource auth
      load_and_authorize_resource(class: Collection, only: %i[index show update destroy])

      # GET api/v2/collections
      def index
        render_ok(
          serialise_collection(
            current_user.collections.kept.order(created_at: :desc)
          )
        )
      end

      # GET api/v2/collections/:id
      def show
        render_ok(serialise(@collection))
      end

      # POST api/v2/collections
      # TODO: update when changing collection params like scenario_ids and interpolated
      def create
        Api::CreateCollection.new.call(
          user: current_user,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection)   { render_created(serialise(collection)) },
          ->(errors) { render_error(serialise_error(collection_params, errors)) }
        )
      end

      # PUT/PATCH api/v2/collections/:id
      # TODO: update when changing collection params like scenario_ids and interpolated
      def update
        Api::UpdateCollection.new.call(
          collection: @collection,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection)   { render_ok(serialise(collection)) },
          ->(errors) { render_error(serialise_error(@collection, errors)) }
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        # TODO: missing Api::DestroyCollection
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
