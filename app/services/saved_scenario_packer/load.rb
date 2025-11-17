# frozen_string_literal: true

require 'zstd-ruby'
require 'rubygems/package'
require 'stringio'
require_relative 'result'

# Loads a saved scenario dump file and restores both ETEngine scenarios and MyETM metadata.
#
# etm_path    - Path to the .etm file containing the dump
# http_client - Faraday HTTP client configured for ETEngine API
# user        - Current user (admin who is performing the load)
#
# Returns Success(LoadResult) or Failure(error_message)
class SavedScenarioPacker::Load
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :file_path # Keep name for backward compat, but it's actually etm_path
  param :http_client
  param :user

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
    # Read and decompress the ETM file
    compressed_data = File.binread(path)
    tar_data = Zstd.decompress(compressed_data)

    # Extract manifest from TAR
    tar_io = StringIO.new(tar_data)
    manifest_content = nil

    Gem::Package::TarReader.new(tar_io) do |tar|
      tar.each do |entry|
        if entry.full_name == 'manifest.json'
          manifest_content = entry.read
          break
        end
      end
    end

    return Failure('manifest.json not found in ETM file') unless manifest_content

    manifest = JSON.parse(manifest_content, symbolize_names: true)
    scenarios_data = manifest[:saved_scenarios] || []

    Success(SavedScenarioPacker::ParsedManifestResult.new(
      manifest: manifest,
      scenarios_data: scenarios_data
    ))
  rescue Zstd::Error => e
    Failure("Failed to decompress ETM file: #{e.message}")
  rescue StandardError => e
    Failure("Failed to parse manifest: #{e.message}")
  end

  def load_scenarios_to_engine(manifest_result)
    mappings = []
    warnings = []

    # Read and decompress the ETM file
    compressed_data = File.binread(file_path)
    tar_data = Zstd.decompress(compressed_data)

    # Extract all scenario dumps from TAR
    scenario_dumps = extract_scenario_dumps_from_tar(tar_data)

    manifest_result.scenarios_data.each do |saved_scenario_data|
      load_single_scenario(scenario_dumps, saved_scenario_data)
        .fmap { |mapping| mappings << mapping }
        .or do |error|
          warnings << error
          Success() # Continue processing other scenarios
        end
    end

    if mappings.empty?
      Failure('No scenarios could be loaded to ETEngine')
    else
      Success(SavedScenarioPacker::LoadedScenariosResult.new(
        mappings: mappings,
        warnings: warnings
      ))
    end
  rescue Zstd::Error => e
    Failure("Failed to decompress ETM file: #{e.message}")
  rescue StandardError => e
    Failure("Failed to load scenarios to engine: #{e.message}")
  end

  def extract_scenario_dumps_from_tar(tar_data)
    dumps = {}
    tar_io = StringIO.new(tar_data)

    Gem::Package::TarReader.new(tar_io) do |tar|
      tar.each do |entry|
        if entry.full_name.start_with?('dumps/')
          dumps[entry.full_name] = entry.read
        end
      end
    end

    dumps
  end

  def load_single_scenario(scenario_dumps, saved_scenario_data)
    original_scenario_id = saved_scenario_data[:scenario_id]
    saved_scenario_id = saved_scenario_data[:saved_scenario_id]

    # Find the dump file for this scenario
    filename = "dumps/scenario_#{original_scenario_id}_saved_#{saved_scenario_id}.json"
    dump_content = scenario_dumps[filename]

    unless dump_content
      return Failure("Dump file not found for scenario #{original_scenario_id}, skipping")
    end

    # Load the scenario to ETEngine
    dump_data = JSON.parse(dump_content)

    response = http_client.post('/api/v3/scenarios/load_dump', dump_data)

    unless response.success?
      return Failure("Failed to load scenario #{original_scenario_id}: #{response.status}")
    end

    # Handle newline-delimited JSON stream response
    parse_load_response(response.body, original_scenario_id)
      .fmap do |new_scenario_id|
        {
          original_scenario_id: original_scenario_id,
          new_scenario_id: new_scenario_id,
          saved_scenario_data: saved_scenario_data
        }
      end
  rescue JSON::ParserError => e
    Failure("Failed to parse dump data for scenario #{original_scenario_id}: #{e.message}")
  rescue StandardError => e
    Failure("Error loading scenario #{original_scenario_id}: #{e.message}")
  end

  def parse_load_response(body, original_scenario_id)
    # Handle newline-delimited JSON stream response
    parsed = if body.is_a?(Hash)
      body
    elsif body.is_a?(String)
      lines = body.strip.split("\n")
      parsed_objects = lines.map { |line| JSON.parse(line) }
      # Last object should contain the scenario ID
      parsed_objects.size == 1 ? parsed_objects.first : parsed_objects.reduce(&:merge)
    else
      return Failure("Unexpected response type for scenario #{original_scenario_id}")
    end

    # Extract scenario ID (handle both string and symbol keys)
    new_scenario_id = parsed['id'] || parsed[:id]

    unless new_scenario_id
      return Failure("No scenario ID in response for #{original_scenario_id}")
    end

    Success(new_scenario_id)
  rescue JSON::ParserError => e
    Failure("Failed to parse JSON response for scenario #{original_scenario_id}: #{e.message}")
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

      Success(SavedScenarioPacker::LoadResult.new(
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

    # Find or create the saved scenario
    saved_scenario = SavedScenario.find_by(id: saved_scenario_data[:saved_scenario_id])

    if saved_scenario
      update_existing_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    else
      create_new_scenario(new_scenario_id, saved_scenario_data)
    end
  rescue StandardError => e
    Failure("Error creating/updating scenario: #{e.message}")
  end

  def update_existing_scenario(saved_scenario, new_scenario_id, saved_scenario_data)
    # Preserve existing scenario history and append the new ID
    history = saved_scenario.scenario_id_history || []
    history += saved_scenario_data[:scenario_id_history] || []
    history << new_scenario_id unless history.include?(new_scenario_id)

    saved_scenario.update!(
      scenario_id: new_scenario_id,
      scenario_id_history: history.uniq
    )

    Success(saved_scenario)
  rescue StandardError => e
    Failure("Failed to update existing scenario #{saved_scenario.id}: #{e.message}")
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

    # Try to find the owner
    owner_data = saved_scenario_data[:owner]
    owner = owner_data ? User.find_by(email: owner_data[:email]) : nil

    if owner.nil? && owner_data
      warnings << "Owner not found: #{owner_data[:email]}, using admin as fallback"
    end

    owner ||= user # Fallback to the admin who is loading

    SavedScenarioUser.create!(
      saved_scenario: saved_scenario,
      user: owner,
      role_id: User::Roles.index_of(:scenario_owner)
    )

    # Add collaborators
    (saved_scenario_data[:collaborators] || []).each do |collab_data|
      collab_user = User.find_by(email: collab_data[:email])

      if collab_user.nil?
        warnings << "Collaborator not found: #{collab_data[:email]}, skipping"
        next
      end

      SavedScenarioUser.create!(
        saved_scenario: saved_scenario,
        user: collab_user,
        role_id: User::Roles.index_of(:scenario_collaborator)
      )
    end

    # Add viewers
    (saved_scenario_data[:viewers] || []).each do |viewer_data|
      viewer_user = User.find_by(email: viewer_data[:email])

      if viewer_user.nil?
        warnings << "Viewer not found: #{viewer_data[:email]}, skipping"
        next
      end

      SavedScenarioUser.create!(
        saved_scenario: saved_scenario,
        user: viewer_user,
        role_id: User::Roles.index_of(:scenario_viewer)
      )
    end

    # Log warnings
    warnings.each { |warning| Rails.logger.warn("User assignment warning: #{warning}") }

    Success()
  rescue StandardError => e
    Failure("Failed to assign users: #{e.message}")
  end

  def handle_failure(error)
    Rails.logger.error("SavedScenarioPacker::Load failed: #{error}")
    Failure("Failed to load dump: #{error}")
  end
end
