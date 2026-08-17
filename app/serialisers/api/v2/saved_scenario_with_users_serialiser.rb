# frozen_string_literal: true

module Api
  module V2
    # A SavedScenario plus who has access to it.
    class SavedScenarioWithUsersSerialiser < SavedScenarioSerialiser
      def as_json(*)
        super.merge(saved_scenario_users: users)
      end

      private

      def users
        saved_scenario.saved_scenario_users.map do |saved_scenario_user|
          { user_id: saved_scenario_user.user_id, role: saved_scenario_user.role.to_s }
        end
      end
    end
  end
end
