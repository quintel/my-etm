# frozen_string_literal: true

module SavedScenarioPacker
  module Results
    # Intermediate result for parsed manifest
    #
    # manifest - Hash of manifest data
    # scenarios_data - Array of scenario metadata from manifest
    ParsedManifestResult = Struct.new(
      :manifest,
      :scenarios_data,
      keyword_init: true
    )
  end
end
