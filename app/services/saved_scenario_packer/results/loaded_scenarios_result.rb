# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Intermediate result for loaded scenarios
    #
    # mappings - Array of hashes with scenario mapping info
    # failures - Array of messages for scenarios that could not be loaded
    LoadedScenariosResult = Struct.new(
      :mappings,
      :failures,
      keyword_init: true
    ) do
      def initialize(mappings:, failures: [])
        super
      end
    end
  end
end
