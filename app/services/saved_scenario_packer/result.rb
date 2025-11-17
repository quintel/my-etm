# frozen_string_literal: true

module SavedScenarioPacker
  # Result value object for Dump service
  #
  # file_path - String path to the created ZIP file
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

  # Intermediate result for parsed manifest
  #
  # manifest - Hash of manifest data
  # scenarios_data - Array of scenario metadata from manifest
  ParsedManifestResult = Struct.new(
    :manifest,
    :scenarios_data,
    keyword_init: true
  )

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
