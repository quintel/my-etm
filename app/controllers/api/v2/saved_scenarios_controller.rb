# frozen_string_literal: true

module Api
  module V2
    class SavedScenariosController < BaseController
      before_action :require_user, only: %i[index]

      load_and_authorize_resource(
        class: SavedScenario, only: %i[index show update destroy discard restore]
      )

      before_action only: %i[create] do
        authorize!(:create, SavedScenario)
      end

      # GET /api/v2/saved_scenarios
      #
      # Scoped based on the caller's access.
      def index
        scenarios = current_user.saved_scenarios
          .available
          .includes(:version)
          .with_rich_text_description
          .order(updated_at: :desc)

        render_collection(scenarios, with: SavedScenarioSerialiser)
      end

      # GET /api/v2/saved_scenarios/:id
      def show
        render_resource(@saved_scenario, with: serialiser_for(@saved_scenario))
      end

      # POST /api/v2/saved_scenarios
      def create
        render_write(
          SavedScenario::Create.call(nil, create_params.to_h.symbolize_keys, current_user),
          status: :created
        )
      end

      # PUT/PATCH /api/v2/saved_scenarios/:id
      def update
        render_write(
          SavedScenario::Update.call(nil, @saved_scenario, update_params.to_h.symbolize_keys)
        )
      end

      # DELETE /api/v2/saved_scenarios/:id
      def destroy
        return render_validation_errors(@saved_scenario.errors) unless @saved_scenario.destroy

        head :no_content
      end

      # PUT /api/v2/saved_scenarios/:id/discard
      def discard
        @saved_scenario.discard

        render_resource(@saved_scenario, with: serialiser_for(@saved_scenario))
      end

      # PUT /api/v2/saved_scenarios/:id/restore
      def restore
        @saved_scenario.undiscard

        render_resource(@saved_scenario, with: serialiser_for(@saved_scenario))
      end

      private

      def render_write(result, status: :ok)
        if result.successful?
          render_resource(result.value, with: serialiser_for(result.value), status: status)
        else
          render_validation_errors(result.value&.errors || { base: result.errors })
        end
      end

      def create_params
        params.require(:saved_scenario).permit(
          :scenario_id, :title, :version, :description, :area_code, :end_year, :private
        )
      end

      def update_params
        params.require(:saved_scenario).permit(:title, :description, :area_code, :end_year, :private)
      end

      def serialiser_for(saved_scenario)
        granted_access?(saved_scenario) ? SavedScenarioWithUsersSerialiser : SavedScenarioSerialiser
      end

      # TODO: Consider this. At the moment
      # A public scenario is readable by anyone, so :read is not a strong enough test for being
      # allowed to see who else has access; only a role granted on the scenario is.
      def granted_access?(saved_scenario)
        return false unless current_user

        current_user.admin? ||
          saved_scenario.saved_scenario_users.exists?(user_id: current_user.id)
      end
    end
  end
end
