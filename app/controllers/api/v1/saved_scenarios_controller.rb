module Api
  module V1
    class SavedScenariosController < BaseController
      load_and_authorize_resource(class: SavedScenario, only: %i[index show create update destroy])

      # GET /saved_scenarios or /saved_scenarios.json
      def index
        saved_scenarios = current_user
          .saved_scenarios
          .available
          .includes(:featured_scenario, :users)
          .order("updated_at DESC")

          render json: saved_scenarios
      end

      def show
        render json: current_user.saved_scenarios.find(params.require(:id))
      end

      # POST api/v1/saved_scenarios
      def create
        result = SavedScenario::Create.call(
          engine_client,
          saved_scenario_params,
          current_user
        )

        if result.successful?
          render json: result.value, status: :created
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT api/v1/saved_scenarios/1
      def update
        result = SavedScenario::Update.call(
          engine_client,
          @saved_scenario,
          saved_scenario_params.except(:version)
        )

        if result.successful?
          render json: result.value, status: :ok
        else
          render json: { errors: result.errors }, status: :unprocessable_entity
        end
      end

      # DELETE /saved_scenarios/1 or /saved_scenarios/1.json
      def destroy
        if @saved_scenario.destroy
          render json: { message: "Scenario deleted successfully" }, status: :ok
        else
          render json: { error: "Failed to delete scenario" }, status: :unprocessable_entity
        end
      end

      private

      # Only allow a list of trusted parameters through.
      def saved_scenario_params
        params.require(:saved_scenario).permit(
          :scenario_id, :title, :version,
          :description, :area_code, :end_year, :private, :discarded
        )
      end

      def engine_client
        MyEtm::Auth.engine_client(
          current_user,
          active_version_tag,
          scopes: doorkeeper_token ? doorkeeper_token.scopes : []
        )
      end

      def active_version_tag
        if Version.tags.include?(saved_scenario_params[:version].to_s)
          saved_scenario_params[:version]
        else
          Version.default.tag
        end
      end
    end
  end
end
