module Api
  module V2
    class CollectionsController < BaseController
      before_action :require_user, only: %i[index]

      load_and_authorize_resource(
        class: Collection, only: %i[index show update destroy discard restore]
      )

      before_action only: %i[create] do
        authorize!(:create, Collection)
      end

      # GET api/v2/collections
      #
      # Scoped based on the caller's access.
      def index
        collections = current_user.collections
          .kept
          .includes(:version, :user, :scenarios, :saved_scenarios)
          .order(created_at: :desc)

        render_collection(collections, with: CollectionSerialiser)
      end

      # GET api/v2/collections/:id
      def show
        render_resource(@collection, with: CollectionSerialiser)
      end

      # POST api/v2/collections
      def create
        Api::CreateCollection.new.call(
          user: current_user,
          params: create_params.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection, with: CollectionSerialiser, status: :created) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # PUT/PATCH api/v2/collections/:id
      def update
        Api::UpdateCollection.new.call(
          collection: @collection,
          params: update_params.to_h.symbolize_keys
        ).either(
          ->(collection) { render_resource(collection, with: CollectionSerialiser) },
          ->(errors)     { render_validation_errors(errors) }
        )
      end

      # DELETE api/v2/collections/:id
      def destroy
        Api::V2::DestroyCollection.new.call(collection: @collection).either(
          ->(_collection) { head :no_content },
          ->(errors)      { render_validation_errors(errors) }
        )
      end

      # PUT api/v2/collections/:id/discard
      def discard
        @collection.discard

        render_resource(@collection, with: CollectionSerialiser)
      end

      # PUT api/v2/collections/:id/restore
      def restore
        @collection.undiscard

        render_resource(@collection, with: CollectionSerialiser)
      end

      private

      # The create contract needs at least one member, and v2 accepts only saved_scenario_ids.
      def create_params
        collection = params.require(:collection)
        collection.require(:saved_scenario_ids)

        collection.permit(
          :title, :area_code, :end_year, :version, :interpolation, saved_scenario_ids: []
        )
      end

      def update_params
        params.require(:collection).permit(:title, :area_code, :end_year, saved_scenario_ids: [])
      end
    end
  end
end
