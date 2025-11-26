# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Result value object for Load service
    #
    # saved_scenarios - Array of SavedScenario records created/updated
    # scenario_mappings - Array of hashes with original_scenario_id => new_scenario_id
    # warnings - Array of warning messages for partial failures (missing users, etc)
    LoadResult = Struct.new(
      :saved_scenarios,
      :scenario_mappings,
      :warnings,
      keyword_init: true
    ) do
      def initialize(saved_scenarios:, scenario_mappings:, warnings: [])
        super
      end
    end
  end
end
