# frozen_string_literal: true

module Api
  module V2
    # Explicit attribute allow-list for SavedScenario, so a new column never joins the public contract
    # silently.
    #
    # Deliberately carries no membership: see SavedScenarioWithUsersSerialiser.
    class SavedScenarioSerialiser
      def initialize(saved_scenario)
        @saved_scenario = saved_scenario
      end

      def as_json(*)
        {
          id: saved_scenario.id,
          title: saved_scenario.title,
          description: saved_scenario.description.to_plain_text.presence,
          scenario_id: saved_scenario.scenario_id,
          area_code: saved_scenario.area_code,
          end_year: saved_scenario.end_year,
          version: saved_scenario.version.tag,
          private: saved_scenario.private,
          discarded_at: saved_scenario.discarded_at,
          created_at: saved_scenario.created_at,
          updated_at: saved_scenario.updated_at
        }
      end

      private

      attr_reader :saved_scenario
    end
  end
end
