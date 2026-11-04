# frozen_string_literal: true

require 'zstd-ruby'

# Loads a saved scenario dump file and restores both ETEngine scenarios and MyETM metadata.
#
# Every load creates new saved scenarios owned by the loading user, on the target version whose
# ETEngine the http_client talks to. Identities and history in the dump belong to the source
# environment and are ignored.
#
# file_path   - Path to the .etm file containing the dump
# http_client - Faraday HTTP client configured for the target version's ETEngine API
# user        - Current user (admin who is performing the load)
# version     - Target version, the default version unless given
#
# Returns Success(LoadResult) or Failure(error_message)
class SavedScenarioPacker::Load
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :file_path
  param :http_client
  param :user
  option :version, default: -> { Version.default }

  def call
    result = validate_etm_file(file_path)
      .bind { |path| extract_and_parse_manifest(path) }
      .bind { |manifest_result| load_scenarios_to_engine(manifest_result) }
      .bind { |load_result| create_saved_scenarios(load_result) }

    result.or { |error| handle_failure(error) }
  end

  private

  def validate_etm_file(path)
    return Failure("File not found: #{path}") unless File.exist?(path)
    return Failure("File is not an ETM file: #{path}") unless path.end_with?('.etm')

    Success(path)
  end

  def extract_and_parse_manifest(path)
    compressed_data = File.binread(path)
    json_data = Zstd.decompress(compressed_data)
    data = JSON.parse(json_data, symbolize_names: true)

    Success(SavedScenarioPacker::Results::ParsedManifestResult.new(
      manifest: data,
      scenarios_data: data[:scenarios] || []
    ))
  rescue Zstd::Error => e
    Failure("Failed to decompress ETM file: #{e.message}")
  rescue JSON::ParserError => e
    Failure("Failed to parse JSON: #{e.message}")
  rescue StandardError => e
    Failure("Failed to read ETM file: #{e.message}")
  end

  def load_scenarios_to_engine(manifest_result)
    mappings = []
    failures = []

    manifest_result.scenarios_data.each do |scenario_data|
      load_single_scenario(scenario_data)
        .fmap { |mapping| mappings << mapping }
        .or do |error|
          failures << error
          Success() # Continue processing other scenarios
        end
    end

    if mappings.empty?
      Failure("No scenarios could be loaded to ETEngine: #{failures.join('; ')}")
    else
      Success(SavedScenarioPacker::Results::LoadedScenariosResult.new(
        mappings: mappings,
        failures: failures
      ))
    end
  rescue StandardError => e
    Failure("Failed to load scenarios to engine: #{e.message}")
  end

  def load_single_scenario(scenario_data)
    original_scenario_id = scenario_data[:scenario_id]

    validate_engine_dump(scenario_data, original_scenario_id)
      .bind { |dump| post_scenario_to_engine(dump, original_scenario_id) }
      .bind { |response| parse_load_response(response.body, original_scenario_id) }
      .fmap { |new_id| build_scenario_mapping(original_scenario_id, new_id, scenario_data) }
  rescue StandardError => e
    Failure("Error loading scenario #{original_scenario_id}: #{e.message}")
  end

  def validate_engine_dump(scenario_data, original_scenario_id)
    engine_dump = scenario_data[:engine_dump]
    return Failure("Engine dump not found for scenario #{original_scenario_id}, skipping") unless engine_dump

    Success(JSON.parse(engine_dump.to_json))
  end

  def post_scenario_to_engine(dump_data, original_scenario_id)
    response = http_client.post('/api/v3/scenarios/load_dump', dump_data)
    return Failure("Failed to load scenario #{original_scenario_id}: #{response.status}") unless response.success?

    Success(response)
  end

  def build_scenario_mapping(original_scenario_id, new_scenario_id, scenario_data)
    {
      original_scenario_id: original_scenario_id,
      new_scenario_id: new_scenario_id,
      saved_scenario_data: scenario_data
    }
  end

  def parse_load_response(body, original_scenario_id)
    parse_response_body(body, original_scenario_id)
      .bind { |parsed| extract_scenario_id(parsed, original_scenario_id) }
  rescue JSON::ParserError => e
    Failure("Failed to parse JSON response for scenario #{original_scenario_id}: #{e.message}")
  end

  def parse_response_body(body, original_scenario_id)
    return Success(body) if body.is_a?(Hash)
    return parse_ndjson_body(body) if body.is_a?(String)

    Failure("Unexpected response type for scenario #{original_scenario_id}")
  end

  def parse_ndjson_body(body)
    lines = body.strip.split("\n")
    parsed_objects = lines.map { |line| JSON.parse(line) }
    result = parsed_objects.size == 1 ? parsed_objects.first : parsed_objects.reduce(&:merge)

    Success(result)
  end

  def extract_scenario_id(parsed, original_scenario_id)
    new_scenario_id = parsed['id'] || parsed[:id]
    return Failure("No scenario ID in response for #{original_scenario_id}") unless new_scenario_id

    Success(new_scenario_id)
  end

  def create_saved_scenarios(load_result)
    failures = load_result.failures.dup
    saved_scenarios = load_result.mappings.filter_map do |mapping|
      create_saved_scenario(mapping).value_or do |error|
        failures << error
        nil
      end
    end

    return Failure("No saved scenarios could be created: #{failures.join('; ')}") if saved_scenarios.empty?

    (failures + warnings).each { |message| Rails.logger.warn("Load warning: #{message}") }
    Success(load_result_for(saved_scenarios, load_result.mappings, failures))
  rescue StandardError => e
    Failure("Failed to create saved scenarios: #{e.message}")
  end

  def load_result_for(saved_scenarios, mappings, failures)
    SavedScenarioPacker::Results::LoadResult.new(
      saved_scenarios: saved_scenarios,
      scenario_mappings: mappings,
      failures: failures,
      warnings: warnings
    )
  end

  def warnings
    @warnings ||= []
  end

  def create_saved_scenario(mapping)
    data = mapping[:saved_scenario_data]
    new_scenario_id = mapping[:new_scenario_id]
    return bind_failure(new_scenario_id) unless bind(new_scenario_id)

    warn_about_version(data)
    persist_saved_scenario(new_scenario_id, data)
      .tap { |saved_scenario| perform_engine_callbacks(saved_scenario) }
      .then { |saved_scenario| Success(saved_scenario) }
  rescue StandardError => e
    bind(new_scenario_id, bound: false)
    Failure("Failed to create #{data[:title]}: #{e.message}")
  end

  def warn_about_version(data)
    return if data[:version_tag].blank? || data[:version_tag] == version.tag

    warnings << "#{data[:title]} was on version #{data[:version_tag]}, loaded onto #{version.tag}"
  end

  def persist_saved_scenario(new_scenario_id, data)
    SavedScenario.transaction do
      SavedScenario.create!(
        scenario_id: new_scenario_id,
        title: data[:title],
        description: data[:description],
        area_code: data[:area_code],
        end_year: data[:end_year],
        private: data[:private],
        version: version
      ).tap { |saved_scenario| assign_owner(saved_scenario) }
    end
  end

  def assign_owner(saved_scenario)
    SavedScenarioUser.create!(
      saved_scenario: saved_scenario,
      user: user,
      role_id: User::Roles.index_of(:scenario_owner)
    )
  end

  # The same protect, set_roles and tag_version callbacks a normal save runs. The saved scenario
  # already exists, so a failure here is a warning rather than a reason to undo it.
  def perform_engine_callbacks(saved_scenario)
    SavedScenario::PerformEngineCallbacks.call(
      http_client, saved_scenario.scenario_id, saved_scenario: saved_scenario
    )
  rescue StandardError => e
    warnings << "ETEngine callbacks failed for #{saved_scenario.title}: #{e.message}"
  end

  def bind(scenario_id, bound: true)
    ApiScenario::SetBound.call(user, version, [ scenario_id ], bound).successful?
  end

  def bind_failure(scenario_id)
    Failure("Failed to bind session #{scenario_id} in ETEngine")
  end

  def handle_failure(error)
    Rails.logger.error("SavedScenarioPacker::Load failed: #{error}")
    Failure("Failed to load dump: #{error}")
  end
end
