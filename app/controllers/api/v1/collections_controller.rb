module Api
  module V1
    class CollectionsController < BaseController
      load_and_authorize_resource(class: Collection, only: %i[index show create destroy])

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
        result = CreateCollection.call(current_user, collection_params)

        if result.successful?
          render json: result.value.as_json, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
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
        params.require(:collection).permit(:title, :version, saved_scenario_ids: [])
      end

      def create_transition_params
        params.require(:collection).permit(saved_scenario_ids: [])
      end
    end
  end
end
