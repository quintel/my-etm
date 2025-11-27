module Api
  module V1
    class CollectionsController < BaseController            
      wrap_parameters false

      check_authorization

      load_and_authorize_resource(class: Collection, only: %i[index show destroy update])

      before_action only: %i[create] do
        # Only check that the user can create, don't load resource as association is not yet made.
        authorize!(:create, Collection)
      end

      # GET /api/v1/collections
      def index
        collections = current_user.collections.kept.order(created_at: :desc)

        render json: {
          collections: collections.as_json
        }, status: :ok
      end

      # GET /api/v1/collections/:id
      def show
        render json: @collection.as_json, status: :ok
      end

      # POST /api/v1/collections
      def create
        Api::CreateCollection.new.call(
          user: current_user,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection)   { render json: collection, status: :created },
          ->(errors) { render json: errors, status: :unprocessable_entity }
        )
      end

      # PUT /api/v1/collection/:id
      def update
        Api::UpdateCollection.new.call(
          collection: @collection,
          params: collection_params.to_h.symbolize_keys
        ).either(
          ->(collection)   { render json: collection, status: :ok },
          ->(errors) { render json: errors, status: :unprocessable_entity }
        )
      end

      # DELETE /api/v1/collections/:id
      def destroy
        if @collection.destroy
          head :no_content
        else
          render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def collection_params
        # Support both flat and nested collection params (Make sure there is no automatic wrapping)
        coll_params = params[:collection].present? ? params.require(:collection) : params
        coll_params.permit(:title, :area_code, :end_year, :version, :interpolation, :discarded, saved_scenario_ids: [], scenario_ids: [])
      end
    end
  end
end
