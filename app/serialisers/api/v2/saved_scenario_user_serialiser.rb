# frozen_string_literal: true

module Api
  module V2
    # Explicit attribute allow-list for SavedScenarioUser batch items.
    class SavedScenarioUserSerialiser
      def initialize(saved_scenario_user)
        @saved_scenario_user = saved_scenario_user
      end

      def as_json(*)
        {
          id: saved_scenario_user.id,
          user_id: saved_scenario_user.user_id,
          user_email: saved_scenario_user.email,
          role: saved_scenario_user.role.to_s
        }
      end

      private

      attr_reader :saved_scenario_user
    end
  end
end
