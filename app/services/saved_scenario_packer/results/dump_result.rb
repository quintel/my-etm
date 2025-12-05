# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Result value object for Dump service
    #
    # file_path - String path to the created ETM file
    # warnings - Array of warning messages for partial failures
    DumpResult = Struct.new(
      :file_path,
      :warnings,
      keyword_init: true
    ) do
      def initialize(file_path:, warnings: [])
        super
      end
    end
  end
end
