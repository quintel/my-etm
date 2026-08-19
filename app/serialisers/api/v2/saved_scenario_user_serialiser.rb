# frozen_string_literal: true

module Api
  module V2
    # Explicit attribute allow-list for a SavedScenarioUser, both as a batch item and embedded in a
    # SavedScenario.
    #
    # `email` resolves through the coupled user, so a caller asking for emails must preload :user.
    class SavedScenarioUserSerialiser
      def initialize(saved_scenario_user, emails: false)
        @saved_scenario_user = saved_scenario_user
        @emails = emails
      end

      def as_json(*)
        json = {
          id: saved_scenario_user.id,
          user_id: saved_scenario_user.user_id,
          role: saved_scenario_user.role.to_s
        }

        @emails ? json.merge(user_email: saved_scenario_user.email) : json
      end

      private

      attr_reader :saved_scenario_user
    end
  end
end
