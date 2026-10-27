# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Result value object for Load service
    #
    # saved_scenarios - Array of SavedScenario records created
    # scenario_mappings - Array of hashes with original_scenario_id => new_scenario_id
    # failures - Array of messages for scenarios that could not be loaded
    # warnings - Array of messages for scenarios that loaded with a caveat
    LoadResult = Struct.new(
      :saved_scenarios,
      :scenario_mappings,
      :failures,
      :warnings,
      keyword_init: true
    ) do
      def initialize(saved_scenarios:, scenario_mappings:, failures: [], warnings: [])
        super
      end
    end
  end
end
