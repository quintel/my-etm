module Api
  module V1
    class SavedScenariosController < BaseController
      check_authorization

      before_action :require_user, only: :index
      load_and_authorize_resource(class: SavedScenario, only: %i[index create show update destroy])
      before_action :load_saved_scenario, only: :show

      # GET /saved_scenarios or /saved_scenarios.json
      def index
        saved_scenarios = current_user
          .saved_scenarios
          .available
          .includes(:featured_scenario, :users)
          .order("updated_at DESC")

          render json: saved_scenarios
      end

      # GET /saved_scenarios/:id
      def show
        render json: @saved_scenario.as_json(
          only: %i[id scenario_id title area_code end_year private version],
          methods: [:saved_scenario_users]
        ).merge("saved_scenario_users" => formatted_saved_scenario_users)
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

      # Load scenario with access control
      def load_saved_scenario
        @saved_scenario = SavedScenario.includes(:saved_scenario_users, :users).find_by(id: params[:id])

        if @saved_scenario.nil?
          render json: { error: "Scenario not found" }, status: :not_found
        elsif !user_has_access?
          render json: { error: "Unauthorized" }, status: :unauthorized
        end
      end

      # Check if user can access the scenario
      def user_has_access?
        return true if !@saved_scenario.private?
        return false unless current_user

        @saved_scenario.users.include?(current_user)
      end

      # Format saved_scenario_users output
      def formatted_saved_scenario_users
        @saved_scenario.saved_scenario_users.map do |ssu|
          { "user_id" => ssu.user_id, "role" => ssu.role }
        end
      end

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
