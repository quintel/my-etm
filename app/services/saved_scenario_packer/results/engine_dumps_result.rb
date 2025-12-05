# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Intermediate result for engine dumps
    #
    # scenarios - Array of SavedScenario records being dumped
    # dumps - Hash of saved_scenario_id => engine_dump_data
    # warnings - Array of warning messages
    EngineDumpsResult = Struct.new(
      :scenarios,
      :dumps,
      :warnings,
      keyword_init: true
    ) do
      def initialize(scenarios:, dumps:, warnings: [])
        super
      end
    end
  end
end
