# frozen_string_literal: true

module Api
  module V2
    # Explicit attribute allow-list for a SavedScenarioUser.
    #
    # A member is addressed by `email`, so it is always served; the membership and user ids are
    # internal. It resolves through the coupled user, so a caller must preload :user.
    class SavedScenarioUserSerialiser
      def initialize(saved_scenario_user)
        @saved_scenario_user = saved_scenario_user
      end

      def as_json(*)
        {
          email: saved_scenario_user.email,
          role: saved_scenario_user.role.to_s,
          pending: saved_scenario_user.pending?
        }
      end

      private

      attr_reader :saved_scenario_user
    end
  end
end
