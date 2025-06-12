module Api
  module V1
    class FeaturedScenariosController < BaseController
      before_action :set_featured_scenario, only: [:show]


      # GET /api/v1/featured_scenarios
      def index
        render json: {
          featured_scenarios: featured_scenarios.as_json
        }, status: :ok
      end

      # GET /api/v1/featured_scenarios/:id
      def show
        render json: @featured_scenario.as_json, status: :ok
      end

      # GET /api/v1/featured_scenarios/scenario_ids
      #
      # Returns the list of scenario_ids associated with the featured scenarios.
      # Used by the dump feature in the Engine
      def scenario_ids
        ids = featured_scenarios
                .includes(:saved_scenario)
                .map { |f| f.saved_scenario.scenario_id }

        render json: { scenario_ids: ids }, status: :ok
      end

      private

      # Find a single FeaturedScenario for the `show` action
      def set_featured_scenario
        @featured_scenario = FeaturedScenario.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: 'FeaturedScenario not found' }, status: :not_found
      end

      def version
        params.permit(:version)
      end

      def featured_scenarios
        if version.present?
          FeaturedScenario.joins(:saved_scenario)
            .where(saved_scenario: { version: Version.find_by(tag: version['version']) })
        else
          FeaturedScenario.all
        end
      end
    end
  end
end
