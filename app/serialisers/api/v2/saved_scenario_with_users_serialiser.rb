# frozen_string_literal: true

module Api
  module V2
    # A SavedScenario plus who has access to it.
    class SavedScenarioWithUsersSerialiser < SavedScenarioSerialiser
      def initialize(saved_scenario, emails: false)
        super(saved_scenario)

        @emails = emails
      end

      def as_json(*)
        super.merge(saved_scenario_users: members)
      end

      private

      def members
        saved_scenario.saved_scenario_users.map do |member|
          SavedScenarioUserSerialiser.new(member, emails: @emails).as_json
        end
      end
    end
  end
end
