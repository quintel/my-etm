# frozen_string_literal: true

require 'zstd-ruby'
require_relative 'result'

# Dumps one or more saved scenarios including their ETEngine session scenario data and MyETM 'metadata'. The dump is
# packaged as a .etm file (JSON compressed with Zstandard).
#
# saved_scenario_ids - Array of SavedScenario IDs to dump
# http_client        - Faraday HTTP client
# user               - Current user
#
# Returns Success(DumpResult) or Failure(error_message)
class SavedScenarioPacker::Dump
  extend Dry::Initializer
  include Dry::Monads[:result]

  param :saved_scenario_ids
  param :http_client
  param :user

  def call
    result = validate_scenarios(saved_scenario_ids)
      .bind { |scenarios| validate_version_consistency(scenarios) }
      .bind { |scenarios| dump_scenarios_from_engine(scenarios) }
      .bind { |engine_result| create_etm_file(engine_result) }

    result.or { |error| cleanup_and_fail(error, result) }
  end

  private

  def validate_scenarios(ids)
    scenarios = SavedScenario.where(id: ids).includes(:version, :users).to_a

    scenarios.empty? ?
      Failure("No saved scenarios found with the provided IDs: #{ids.join(', ')}") :
      Success(scenarios)
  end

  # You can't currently load scenarios from different versions simultaneously
  def validate_version_consistency(scenarios)
    versions = scenarios.map { |ss| ss.version&.tag }.compact.uniq

    if versions.length > 1
      Rails.logger.warn(
        "Dumping scenarios from multiple versions: #{versions.join(', ')}. " \
        'This will cause issues when loading.'
      )
    end

    Success(scenarios)
  end

  # Calls the engine streaming endpoint to get all dumps in a single request
  # Uses Faraday's on_data callback to process NDJSON chunks incrementally
  def dump_scenarios_from_engine(scenarios)
    scenario_ids = scenarios.map(&:scenario_id)
    dumps = []
    buffer = ''.dup
    parse_errors = []

    response = http_client.post('/api/v3/scenarios/stream') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { ids: scenario_ids }.to_json

      # Stream chunks as they arrive and parse NDJSON incrementally
      req.options.on_data = Proc.new do |chunk, _overall_bytes|
        buffer << chunk

        # Process complete lines (ending with newline)
        while (nl_idx = buffer.index("\n"))
          line = buffer.slice!(0..nl_idx).strip
          next if line.empty?

          begin
            dumps << JSON.parse(line)
          rescue JSON::ParserError => e
            parse_errors << "Failed to parse NDJSON line: #{e.message}"
          end
        end
      end
    end

    # Check response status
    unless response.success?
      return Failure("Failed to dump scenarios from ETEngine: #{response.status}")
    end

    # Handle any trailing data in buffer
    if buffer.strip.present?
      begin
        dumps << JSON.parse(buffer.strip)
      rescue JSON::ParserError => e
        parse_errors << "Failed to parse trailing NDJSON data: #{e.message}"
      end
    end

    # Log parse errors if any
    parse_errors.each { |error| Rails.logger.warn("SavedScenarioPacker::Dump - #{error}") }

    # Match dumps to SavedScenarios and collect warnings
    match_dumps_to_scenarios(dumps, scenarios)
  rescue StandardError => e
    Failure("Error dumping scenarios: #{e.message}")
  end

  # Match engine dumps to SavedScenarios by scenario_id
  def match_dumps_to_scenarios(dumps, scenarios)
    engine_dumps = {}
    warnings = []

    scenarios.each do |saved_scenario|
      dump = dumps.find { |d| d.dig('metadata', 'id') == saved_scenario.scenario_id }

      if dump
        engine_dumps[saved_scenario.id] = dump
      else
        warnings << "Failed to dump scenario #{saved_scenario.scenario_id} for " \
                    "saved scenario #{saved_scenario.id}: not found in engine response"
      end
    end

    if engine_dumps.empty?
      Failure('No scenarios could be dumped from ETEngine')
    else
      Success(SavedScenarioPacker::EngineDumpsResult.new(
        scenarios: scenarios.select { |ss| engine_dumps.key?(ss.id) },
        dumps: engine_dumps,
        warnings: warnings
      ))
    end
  end

  def create_etm_file(engine_result)
    temp_dir_path = create_temp_dir
    file_path = File.join(temp_dir_path, generate_filename(engine_result.scenarios.count))

    # Create combined JSON structure with manifest data and engine dumps
    json_data = generate_combined_json(engine_result)

    # Compress with Zstandard
    compressed_data = Zstd.compress(json_data)

    # Write to file
    File.binwrite(file_path, compressed_data)

    Success(SavedScenarioPacker::DumpResult.new(
      file_path: file_path,
      scenario_count: engine_result.scenarios.count,
      warnings: engine_result.warnings,
      temp_dir: temp_dir_path
    ))
  rescue StandardError => e
    Failure("Failed to create ETM file: #{e.message}")
  end

  def generate_combined_json(engine_result)
    manifest = SavedScenarioPacker::Manifest.new(engine_result.scenarios)
    manifest_data = JSON.parse(manifest.to_json)

    # Combine manifest scenarios with their engine dumps
    combined_scenarios = manifest_data['saved_scenarios'].map do |scenario_data|
      saved_scenario_id = scenario_data['saved_scenario_id']
      engine_dump = engine_result.dumps[saved_scenario_id]

      scenario_data.merge('engine_dump' => engine_dump)
    end

    # Create final structure
    result = manifest_data.merge('scenarios' => combined_scenarios)
    result.delete('saved_scenarios') # Remove old key

    JSON.pretty_generate(result)
  end

  def create_temp_dir
    dir = Rails.root.join('tmp', 'saved_scenario_dumps')
    FileUtils.mkdir_p(dir)
    dir
  end

  def generate_filename(count)
    date = Time.current.strftime('%d%m%Y')
    env = Rails.env.production? ? 'pro' : Rails.env
    "#{count}_scenarios_#{env}_#{date}.etm"
  end

  def cleanup_and_fail(error, result)
    Rails.logger.error("SavedScenarioPacker::Dump failed: #{error}")

    # Log warnings if any were collected
    if result.success? && result.value!.respond_to?(:warnings)
      result.value!.warnings.each { |warning| Rails.logger.warn(warning) }
    end

    # Clean up temp directory if it was created
    if result.success? && result.value!.respond_to?(:temp_dir)
      cleanup_temp_dir(result.value!.temp_dir)
    end

    Failure("Failed to create dump: #{error}")
  end

  def cleanup_temp_dir(temp_dir)
    FileUtils.rm_rf(temp_dir) if temp_dir && Dir.exist?(temp_dir)
  rescue StandardError => e
    Rails.logger.error("Failed to cleanup temp directory: #{e.message}")
  end
end
