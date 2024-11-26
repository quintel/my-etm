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

      # POST /saved_scenarios or /saved_scenarios.json
      def create
        @saved_scenario = SavedScenario.new(saved_scenario_params)
        if @saved_scenario.save
          # Associate the saved scenario with the current user
          SavedScenarioUser.create!(
            saved_scenario: @saved_scenario,
            user: current_user,
            role_id: User::Roles.index_of(:scenario_owner)
          )

          render json: @saved_scenario, status: :created
        else
          render json: { errors: @saved_scenario.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /saved_scenarios/1 or /saved_scenarios/1.json
      def update
        if @saved_scenario.update_with_api_params(saved_scenario_params)
          render json: @saved_scenario, status: :ok
        else
          render json: @saved_scenario.errors, status: :unprocessable_entity
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
          :scenario_id, :title,
          :description, :area_code, :end_year, :private, :discarded
        )
      end
    end
  end
end
