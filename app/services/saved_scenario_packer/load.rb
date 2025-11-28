# frozen_string_literal: true

require 'zstd-ruby'

# Loads a saved scenario dump file and restores both ETEngine scenarios and MyETM metadata.
#
# file_path             - Path to the .etm file containing the dump
# http_client           - Faraday HTTP client configured for ETEngine API
# user                  - Current user (admin who is performing the load)
# on_duplicate_handler  - Optional callable for handling duplicate scenarios
#                         Called with (saved_scenario, saved_scenario_data)
#                         Should return :update or :create
#                         If nil, defaults to :update (existing behavior)
#
# Returns Success(LoadResult) or Failure(error_message)
class SavedScenarioPacker::Load
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :file_path
  param :http_client
  param :user
  option :on_duplicate_handler, default: -> { nil }

  def call
    result = validate_etm_file(file_path)
      .bind { |path| extract_and_parse_manifest(path) }
      .bind { |manifest_result| load_scenarios_to_engine(manifest_result) }
      .bind { |load_result| create_or_update_saved_scenarios(load_result) }

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
    warnings = []

    manifest_result.scenarios_data.each do |scenario_data|
      load_single_scenario(scenario_data)
        .fmap { |mapping| mappings << mapping }
        .or do |error|
          warnings << error
          Success() # Continue processing other scenarios
        end
    end

    if mappings.empty?
      Failure('No scenarios could be loaded to ETEngine')
    else
      Success(SavedScenarioPacker::Results::LoadedScenariosResult.new(
        mappings: mappings,
        warnings: warnings
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

  def create_or_update_saved_scenarios(load_result)
    saved_scenarios = []
    warnings = load_result.warnings.dup

    load_result.mappings.each do |mapping|
      create_or_update_scenario(mapping)
        .fmap { |scenario| saved_scenarios << scenario }
        .or do |error|
          warnings << error
          Success() # Continue processing other scenarios
        end
    end

    if saved_scenarios.empty?
      Failure('No saved scenarios could be created or updated')
    else
      # Log all warnings
      warnings.each { |warning| Rails.logger.warn("Load warning: #{warning}") }

      Success(SavedScenarioPacker::Results::LoadResult.new(
        saved_scenarios: saved_scenarios,
        scenario_mappings: load_result.mappings,
        warnings: warnings
      ))
    end
  rescue StandardError => e
    Failure("Failed to create/update saved scenarios: #{e.message}")
  end

  def create_or_update_scenario(mapping)
    saved_scenario_data = mapping[:saved_scenario_data]
    new_scenario_id = mapping[:new_scenario_id]
    saved_scenario = SavedScenario.find_by(id: saved_scenario_data[:saved_scenario_id])

    if saved_scenario
      handle_duplicate_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    else
      create_new_scenario(new_scenario_id, saved_scenario_data)
    end
  rescue StandardError => e
    Failure("Error creating/updating scenario: #{e.message}")
  end

  def handle_duplicate_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    strategy = determine_duplicate_strategy(saved_scenario, saved_scenario_data)

    case strategy
    when :update
      update_existing_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    when :create
      create_new_scenario(new_scenario_id, saved_scenario_data)
    else
      Failure("Unknown duplicate handling strategy: #{strategy}")
    end
  end

  def determine_duplicate_strategy(saved_scenario, saved_scenario_data)
    return :update unless on_duplicate_handler

    on_duplicate_handler.call(saved_scenario, saved_scenario_data)
  end

  def update_existing_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    history = build_scenario_history(
      saved_scenario.scenario_id_history,
      saved_scenario_data[:scenario_id_history],
      new_scenario_id
    )

    saved_scenario.update!(
      scenario_id: new_scenario_id,
      scenario_id_history: history
    )

    Success(saved_scenario)
  rescue StandardError => e
    Failure("Failed to update existing scenario #{saved_scenario.id}: #{e.message}")
  end

  def build_scenario_history(existing_history, dump_history, new_scenario_id)
    history = existing_history || []
    history += dump_history || []
    history << new_scenario_id unless history.include?(new_scenario_id)
    history.uniq
  end

  def create_new_scenario(new_scenario_id, saved_scenario_data)
    version = Version.find_by(tag: saved_scenario_data[:version_tag]) || Version.default

    # Preserve scenario history from the dump
    history = (saved_scenario_data[:scenario_id_history] || []) + [new_scenario_id]

    saved_scenario = SavedScenario.create!(
      scenario_id: new_scenario_id,
      title: saved_scenario_data[:title],
      description: saved_scenario_data[:description],
      area_code: saved_scenario_data[:area_code],
      end_year: saved_scenario_data[:end_year],
      private: saved_scenario_data[:private],
      version: version,
      scenario_id_history: history.uniq
    )

    # Assign users
    assign_users_to_scenario(saved_scenario, saved_scenario_data)
      .fmap { saved_scenario }
  rescue StandardError => e
    Failure("Failed to create new scenario: #{e.message}")
  end

  def assign_users_to_scenario(saved_scenario, saved_scenario_data)
    warnings = []

    assign_owner(saved_scenario, saved_scenario_data[:owner], warnings)
    assign_role_users(saved_scenario, saved_scenario_data[:collaborators], :scenario_collaborator, warnings)
    assign_role_users(saved_scenario, saved_scenario_data[:viewers], :scenario_viewer, warnings)

    log_user_assignment_warnings(warnings)
    Success()
  rescue StandardError => e
    Failure("Failed to assign users: #{e.message}")
  end

  def assign_owner(saved_scenario, owner_data, warnings)
    if owner_data && owner_data[:email]
      owner_user = User.find_by(email: owner_data[:email])

      if owner_user
        SavedScenarioUser.create!(
          saved_scenario: saved_scenario,
          user: owner_user,
          role_id: User::Roles.index_of(:scenario_owner)
        )
      else
        warnings << "Owner not found: #{owner_data[:email]}, creating pending user"
        SavedScenarioUser.create!(
          saved_scenario: saved_scenario,
          user_email: owner_data[:email],
          role_id: User::Roles.index_of(:scenario_owner)
        )
      end
    else
      SavedScenarioUser.create!(
        saved_scenario: saved_scenario,
        user: user,
        role_id: User::Roles.index_of(:scenario_owner)
      )
    end
  end

  def assign_role_users(saved_scenario, users_data, role, warnings)
    return unless users_data

    users_data.each do |user_data|
      assign_role_user(saved_scenario, user_data, role, warnings)
    end
  end

  def assign_role_user(saved_scenario, user_data, role, warnings)
    found_user = User.find_by(email: user_data[:email])

    if found_user
      SavedScenarioUser.create!(
        saved_scenario: saved_scenario,
        user: found_user,
        role_id: User::Roles.index_of(role)
      )
    else
      warnings << "#{role.to_s.split('_').last.capitalize} not found: #{user_data[:email]}, creating pending user"
      SavedScenarioUser.create!(
        saved_scenario: saved_scenario,
        user_email: user_data[:email],
        role_id: User::Roles.index_of(role)
      )
    end
  end

  def log_user_assignment_warnings(warnings)
    warnings.each { |warning| Rails.logger.warn("User assignment warning: #{warning}") }
  end

  def handle_failure(error)
    Rails.logger.error("SavedScenarioPacker::Load failed: #{error}")
    Failure("Failed to load dump: #{error}")
  end
end
