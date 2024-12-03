# app/controllers/api/collections_controller.rb
module Api
  module V1
    class CollectionsController < BaseController
      before_action :ensure_valid_config
      before_action :set_collection, only: %i[show destroy]

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
          render json: result.collection.as_json, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # POST /api/v1/collections/create_transition
      def create_transition
        result = CreateInterpolatedCollection.call(
          MyEtm::Auth.engine_client(current_user),
          current_user.saved_scenarios.find(create_transition_params[:saved_scenario_ids]),
          current_user
        )

        if result.successful?
          render json: result.collection.as_json, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/collections/:id
      def destroy
        if @collection.discard
          head :no_content
        else
          render json: { errors: @collection.errors.full_messages }, status: :unprocessable_entity
        end
      end

      private

      def set_collection
        @collection = current_user.collections.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'Collection not found' }, status: :not_found
      end

      def collection_params
        params.require(:collection).permit(:title, :version, saved_scenario_ids: [])
      end

      def create_transition_params
        params.require(:collection).permit(saved_scenario_ids: [])
      end

      def ensure_valid_config
        return if Settings.collections_url

        render json: { error: 'Missing collections_url setting in config.yml' }, status: :unprocessable_entity
      end
    end
  end
end
