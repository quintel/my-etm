# frozen_string_literal: true

module Api
  module V2
    # TEMPORARY(legacy-pat): tells ETEngine which grant a PAT's user holds on one Session, so pyETM
    # 2.0 keeps working once the engine authorizes from grants alone. Removed when V3 is retired.
    class LegacyGrantsController < BaseController
      # The answer covers only the caller's own roles, so no ability applies
      skip_authorization_check

      before_action :require_personal_access_token

      # GET /api/v2/legacy_grants/:session_id
      def show
        render_resource(granted_access, with: ScenarioAccessSerialiser)
      end

      private

      # A kept scenario's current Session gets the role's level, one in its history gets read
      def granted_access
        session_id = params[:session_id].to_i
        levels = scenarios_with_role.filter_map do |saved_scenario|
          if saved_scenario.scenario_id == session_id
            ScenarioAccess.level_of(saved_scenario.role_id)
          elsif saved_scenario.scenario_id_history.include?(session_id)
            ScenarioAccess::READ
          end
        end

        ScenarioAccess.new.grant(levels.map { |level| [ session_id, level ] })
      end

      # Loads every scenario the caller has a role on; query the history instead if that grows large
      def scenarios_with_role
        ScenarioAccess.roles_of(current_user.id)
          .select(:scenario_id, :scenario_id_history, "saved_scenario_users.role_id")
      end

      def require_personal_access_token
        render_unauthenticated unless PersonalAccessToken.prefixed?(current_token.token)
      end
    end
  end
end
