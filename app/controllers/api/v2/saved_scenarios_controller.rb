# frozen_string_literal: true

module Api
  module V2
    class SavedScenariosController < BaseController
      self.resource_param_key = :saved_scenario

      before_action :require_user, only: %i[index]

      load_and_authorize_resource(
        class: SavedScenario, only: %i[show update destroy discard restore]
      )

      authorize_resource(class: SavedScenario, only: %i[index])

      before_action only: %i[create] do
        authorize!(:create, SavedScenario)
      end

      # GET /api/v2/saved_scenarios
      #
      # The caller's own scenarios, then filtered by the ability.
      # TODO: unpaginated.
      def index
        scenarios = current_user.saved_scenarios
          .accessible_by(current_ability)
          .available
          .includes(:version)
          .with_rich_text_description
          .order(updated_at: :desc)

        render_collection(scenarios, with: SavedScenarioSerialiser)
      end

      # GET /api/v2/saved_scenarios/:id
      def show
        render_resource(@saved_scenario, **view_for(@saved_scenario))
      end

      # POST /api/v2/saved_scenarios
      def create
        result = SavedScenario::Create.call(nil, create_params, current_user)
        reset_ability! if result.successful?

        render_write(result, status: :created)
      end

      # PUT/PATCH /api/v2/saved_scenarios/:id
      def update
        render_write(
          SavedScenario::Update.call(nil, @saved_scenario, update_params)
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

        render_resource(@saved_scenario, **view_for(@saved_scenario))
      end

      # PUT /api/v2/saved_scenarios/:id/restore
      def restore
        @saved_scenario.undiscard

        render_resource(@saved_scenario, **view_for(@saved_scenario))
      end

      private

      def render_write(result, status: :ok)
        if result.successful?
          render_resource(result.value, **view_for(result.value), status: status)
        else
          render_validation_errors(result.value&.errors || { base: result.errors })
        end
      end

      def request_members
        %i[scenario_id title version description area_code end_year private]
      end

      def create_params
        params.require(:saved_scenario).permit(
          :scenario_id, :title, :version, :description, :area_code, :end_year, :private
        )
      end

      def update_params
        params.require(:saved_scenario).permit(:title, :description, :area_code, :end_year, :private)
      end

      # A public scenario is readable by anyone, so :read is not sufficient here
      def view_for(saved_scenario)
        return { with: SavedScenarioSerialiser } unless role_holder?(saved_scenario)

        emails = can?(:update, saved_scenario)
        preload_members(saved_scenario) if emails

        { with: SavedScenarioWithUsersSerialiser, options: { emails: emails } }
      end

      def role_holder?(saved_scenario)
        return false unless current_user

        current_user.admin? || saved_scenario.saved_scenario_users.any? do |member|
          member.user_id == current_user.id
        end
      end

      def preload_members(saved_scenario)
        ActiveRecord::Associations::Preloader.new(
          records: saved_scenario.saved_scenario_users.to_a, associations: :user
        ).call
      end
    end
  end
end
