# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Result value object for Dump service
    #
    # file_path - String path to the created ETM file
    # scenario_count - Integer count of successfully dumped scenarios
    # warnings - Array of warning messages for partial failures
    # temp_dir - String path to temporary directory (for cleanup)
    DumpResult = Struct.new(
      :file_path,
      :scenario_count,
      :warnings,
      :temp_dir,
      keyword_init: true
    ) do
      def initialize(file_path:, scenario_count:, warnings: [], temp_dir: nil)
        super
      end
    end
  end
end
