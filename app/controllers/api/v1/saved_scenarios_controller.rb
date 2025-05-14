module Api
  module V1
    class SavedScenariosController < BaseController
      check_authorization

      load_and_authorize_resource(class: SavedScenario, only: %i[index create show update destroy])

      # GET /saved_scenarios or /saved_scenarios.json
      def index
        base =
          if params[:scope] == 'all'
            SavedScenario.accessible_by(current_ability)
          elsif current_user
            current_user
              .saved_scenarios
              .accessible_by(current_ability)
          else
            SavedScenario.none
          end

        @saved_scenarios = base
          .available
          .includes(:featured_scenario, :users)
          .order(updated_at: :desc)

        render json: @saved_scenarios
      end

      # GET /saved_scenarios/:id
      def show
        render json: @saved_scenario
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
          active_version,
          scopes: doorkeeper_token ? doorkeeper_token.scopes : []
        )
      end

      def active_version
        Version.find_by(tag: saved_scenario_params[:version]) || Version.default
      end
    end
  end
end
