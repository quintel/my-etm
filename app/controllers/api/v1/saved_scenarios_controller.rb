module Api
  module V1
    class SavedScenariosController < BaseController
      render json:

      load_and_authorize_resource(class: SavedScenario, only: %i[index show create update destroy])

      # GET /saved_scenarios or /saved_scenarios.json
      def index
        saved_scenarios = current_user
          .saved_scenarios
          .available
          .includes(:featured_scenario, :users)
          .order('updated_at DESC')

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
        respond_to do |format|
          if @saved_scenario.update(saved_scenario_update_params)
            render json: @saved_scenario, status: :ok
          else
            render json: @saved_scenario.errors, status: :unprocessable_entity
          end
        end
      end

      # DELETE /saved_scenarios/1 or /saved_scenarios/1.json
      def destroy
        @saved_scenario.destroy
        render status: :ok
      end


      private

      # Only allow a list of trusted parameters through.
      def saved_scenario_params
        params.require(:saved_scenario).permit(
          :scenario_id, :scenario_id_history, :title,
          :description, :area_code, :end_year, :private
        )
      end

      # Only allow a list of trusted parameters through.
      def saved_scenario_update_params
        params.require(:saved_scenario).permit(
          :title, :description
        )
      end

      def hydrate_scenarios(saved_scenarios)
        scenarios = Scenario
          .accessible_by(current_ability)
          .where(id: saved_scenarios.map { |s| s['scenario_id'] })
          .includes(:scaler, :users)
          .index_by(&:id)

        saved_scenarios.map do |saved_scenario|
          scenario   = scenarios[saved_scenario['scenario_id']]
          serialized = scenario ? ScenarioSerializer.new(self, scenario).as_json : nil

          saved_scenario[:scenario] = serialized
          saved_scenario
        end
      end

      def hydrate_scenario(saved_scenario)
        hydrate_scenarios([saved_scenario]).first
      end
    end
  end
end
