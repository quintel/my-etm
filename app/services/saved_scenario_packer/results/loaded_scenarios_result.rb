# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Intermediate result for loaded scenarios
    #
    # mappings - Array of hashes with scenario mapping info
    # warnings - Array of warning messages
    LoadedScenariosResult = Struct.new(
      :mappings,
      :warnings,
      keyword_init: true
    ) do
      def initialize(mappings:, warnings: [])
        super
      end
    end
  end
end
