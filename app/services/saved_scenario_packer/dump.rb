# frozen_string_literal: true

require 'zstd-ruby'
require 'rubygems/package'
require 'stringio'
require_relative 'result'

# Dumps one or more saved scenarios including their ETEngine session scenario data and MyETM 'metadata'. The dump is
# packaged as a .etm file (which is a TAR archive compressed with Zstandard).
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
  def dump_scenarios_from_engine(scenarios)
    scenario_ids = scenarios.map(&:scenario_id)

    # Make single HTTP request with all scenario IDs
    response = http_client.get('/api/v3/scenarios/dump', ids: scenario_ids)

    unless response.success?
      return Failure("Failed to dump scenarios from ETEngine: #{response.status}")
    end

    # Parse NDJSON stream and match dumps to SavedScenarios
    parse_ndjson_stream(response.body, scenarios)
  rescue StandardError => e
    Failure("Error dumping scenarios: #{e.message}")
  end

  def parse_ndjson_stream(body, scenarios)
    # Parse NDJSON stream - one JSON object per line
    lines = body.is_a?(String) ? body.strip.split("\n") : []
    dumps = lines.reject(&:empty?).map { |line| JSON.parse(line) }

    # Match dumps to SavedScenarios by original_scenario_id
    engine_dumps = {}
    warnings = []

    scenarios.each do |saved_scenario|
      dump = dumps.find { |d| d['original_scenario_id'] == saved_scenario.scenario_id }

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
  rescue JSON::ParserError => e
    Failure("Failed to parse JSON response: #{e.message}")
  end

  def create_etm_file(engine_result)
    temp_dir_path = create_temp_dir
    etm_path = File.join(temp_dir_path, generate_filename(engine_result.scenarios.count))

    # Create TAR archive in memory
    tar_data = create_tar_archive(engine_result)

    # Compress with Zstandard (using default compression level of 3, adjust if CPU usage is too high or speed too slow)
    compressed_data = Zstd.compress(tar_data)

    # Write to file
    File.binwrite(etm_path, compressed_data)

    Success(SavedScenarioPacker::DumpResult.new(
      file_path: etm_path, # Keep field name for backward compat with result object
      scenario_count: engine_result.scenarios.count,
      warnings: engine_result.warnings,
      temp_dir: temp_dir_path
    ))
  rescue StandardError => e
    Failure("Failed to create ETM file: #{e.message}")
  end

  def create_tar_archive(engine_result)
    tar_io = StringIO.new

    Gem::Package::TarWriter.new(tar_io) do |tar|
      # Add manifest.json which contains the saved scenario info
      manifest_content = generate_manifest(engine_result)
      add_file_to_tar(tar, 'manifest.json', manifest_content)

      # Add 'session' scenario dump
      engine_result.dumps.each do |saved_scenario_id, dump_data|
        filename = "dumps/scenario_#{dump_data['original_scenario_id']}_saved_#{saved_scenario_id}.json"
        dump_content = JSON.pretty_generate(dump_data)
        add_file_to_tar(tar, filename, dump_content)
      end
    end

    tar_io.string
  end

  def add_file_to_tar(tar, filename, content)
    tar.add_file_simple(filename, 0644, content.bytesize) do |io|
      io.write(content)
    end
  end

  def generate_manifest(engine_result)
    manifest = SavedScenarioPacker::Manifest.new(engine_result.scenarios)
    manifest.to_json
  end

  def create_temp_dir
    dir = Rails.root.join('tmp', 'saved_scenario_dumps')
    FileUtils.mkdir_p(dir)
    dir
  end

  def generate_filename(count)
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    env = Rails.env.production? ? 'pro' : Rails.env
    "#{count}_scenarios_#{env}_#{timestamp}.etm"
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
