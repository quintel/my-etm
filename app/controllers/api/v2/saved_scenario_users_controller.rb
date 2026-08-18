# frozen_string_literal: true

module Api
  module V2
    class SavedScenarioUsersController < BaseController
      load_and_authorize_resource :saved_scenario, only: %i[create update destroy]

      before_action only: %i[create update destroy] do
        authorize!(:update, @saved_scenario)
      end

      # POST /api/v2/saved_scenarios/:saved_scenario_id/users
      def create
        result = CreateSavedScenarioUser.call(
          nil,
          @saved_scenario,
          current_user.name,
          bulk_user_params,
          user: current_user,
          sync_to_engine: false
        )

        render_users(result)
      end

      # PUT/PATCH /api/v2/saved_scenarios/:saved_scenario_id/users
      def update
        result = UpdateSavedScenarioUser.call(
          nil,
          @saved_scenario,
          bulk_user_params,
          user: current_user,
          sync_to_engine: false
        )

        render_users(result)
      end

      # DELETE /api/v2/saved_scenarios/:saved_scenario_id/users
      def destroy
        result = DestroySavedScenarioUser.call(
          nil,
          @saved_scenario,
          bulk_user_params,
          user: current_user,
          sync_to_engine: false
        )

        render_users(result)
      end

      private

      def render_users(result)
        render_bulk(
          result,
          with: SavedScenarioUserSerialiser,
          options: { emails: true },
          pointer: "/saved_scenario_users"
        )
      end

      def request_members
        %i[saved_scenario_users]
      end

      def permitted_params
        params.permit(saved_scenario_users: %i[id role user_id user_email])
      end

      # `require` answers an absent or empty list as param_missing, but cannot tell a list from an
      # object, so the shape is checked separately.
      def bulk_user_params
        submitted = permitted_params.require(:saved_scenario_users)
        raise InvalidParam.new("/saved_scenario_users", "saved_scenario_users must be an array") unless
          submitted.is_a?(Array)

        submitted.map { |user_params| scenario_user_params(user_params) }
      end

      def scenario_user_params(user_params)
        {
          id: user_params[:id]&.to_i,
          role_id: User::Roles.index_of(user_params[:role]&.to_sym),
          user_id: user_params[:user_id].presence&.to_i,
          user_email: user_params[:user_email]
        }
      end
    end
  end
end
