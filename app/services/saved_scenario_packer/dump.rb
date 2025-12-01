# frozen_string_literal: true

require 'zstd-ruby'

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

  def dump_scenarios_from_engine(scenarios)
    scenario_ids = scenarios.map(&:scenario_id)
    dumps, parse_errors = stream_scenarios_from_engine(scenario_ids)

    log_parse_errors(parse_errors)
    match_dumps_to_scenarios(dumps, scenarios)
  rescue StandardError => e
    Failure("Error dumping scenarios: #{e.message}")
  end

  def stream_scenarios_from_engine(scenario_ids)
    dumps = []
    buffer = ''.dup
    parse_errors = []

    response = post_streaming_request(scenario_ids, dumps, buffer, parse_errors)

    return [dumps, parse_errors] unless response.success?

    process_trailing_buffer(buffer, dumps, parse_errors)
    [dumps, parse_errors]
  end

  def post_streaming_request(scenario_ids, dumps, buffer, parse_errors)
    http_client.post('/api/v3/scenarios/stream') do |req|
      req.headers['Content-Type'] = 'application/json'
      req.body = { ids: scenario_ids }.to_json
      req.options.on_data = build_ndjson_processor(dumps, buffer, parse_errors)
    end
  end

  def build_ndjson_processor(dumps, buffer, parse_errors)
    Proc.new do |chunk, _overall_bytes|
      buffer << chunk
      process_complete_lines(buffer, dumps, parse_errors)
    end
  end

  def process_complete_lines(buffer, dumps, parse_errors)
    while (nl_idx = buffer.index("\n"))
      line = buffer.slice!(0..nl_idx).strip
      next if line.empty?

      parse_ndjson_line(line, dumps, parse_errors)
    end
  end

  def parse_ndjson_line(line, dumps, parse_errors)
    dumps << JSON.parse(line)
  rescue JSON::ParserError => e
    parse_errors << "Failed to parse NDJSON line: #{e.message}"
  end

  def process_trailing_buffer(buffer, dumps, parse_errors)
    return unless buffer.strip.present?

    dumps << JSON.parse(buffer.strip)
  rescue JSON::ParserError => e
    parse_errors << "Failed to parse trailing NDJSON data: #{e.message}"
  end

  def log_parse_errors(parse_errors)
    parse_errors.each { |error| Rails.logger.warn("SavedScenarioPacker::Dump - #{error}") }
  end

  def match_dumps_to_scenarios(dumps, scenarios)
    engine_dumps, warnings = build_engine_dumps_map(dumps, scenarios)

    return Failure('No scenarios could be dumped from ETEngine') if engine_dumps.empty?

    Success(SavedScenarioPacker::Results::EngineDumpsResult.new(
      scenarios: scenarios.select { |ss| engine_dumps.key?(ss.id) },
      dumps: engine_dumps,
      warnings: warnings
    ))
  end

  def build_engine_dumps_map(dumps, scenarios)
    engine_dumps = {}
    warnings = []

    scenarios.each do |saved_scenario|
      match_scenario_dump(saved_scenario, dumps, engine_dumps, warnings)
    end

    [engine_dumps, warnings]
  end

  def match_scenario_dump(saved_scenario, dumps, engine_dumps, warnings)
    dump = dumps.find { |d| d.dig('metadata', 'id') == saved_scenario.scenario_id }

    if dump
      engine_dumps[saved_scenario.id] = dump
    else
      warnings << "Failed to dump scenario #{saved_scenario.scenario_id} for " \
                  "saved scenario #{saved_scenario.id}: not found in engine response"
    end
  end

  def create_etm_file(engine_result)
    filename = generate_filename
    tempfile = Tempfile.new([filename.chomp('.etm'), '.etm'])
    tempfile.binmode

    write_compressed_file(tempfile, engine_result)
    tempfile.close

    Success(build_dump_result(tempfile.path, engine_result))
  rescue StandardError => e
    tempfile&.close
    tempfile&.unlink
    Failure("Failed to create ETM file: #{e.message}")
  end

  def write_compressed_file(file, engine_result)
    json_data = generate_combined_json(engine_result)
    compressed_data = Zstd.compress(json_data)
    file.write(compressed_data)
  end

  def build_dump_result(file_path, engine_result)
    SavedScenarioPacker::Results::DumpResult.new(
      file_path: file_path,
      warnings: engine_result.warnings
    )
  end

  def generate_combined_json(engine_result)
    manifest = SavedScenarioPacker::Manifest.new(engine_result.scenarios)
    manifest_data = JSON.parse(manifest.to_json)

    combined_scenarios = merge_scenarios_with_dumps(manifest_data, engine_result)
    final_structure = build_final_json_structure(manifest_data, combined_scenarios)

    JSON.pretty_generate(final_structure)
  end

  def merge_scenarios_with_dumps(manifest_data, engine_result)
    manifest_data['saved_scenarios'].map do |scenario_data|
      saved_scenario_id = scenario_data['saved_scenario_id']
      engine_dump = engine_result.dumps[saved_scenario_id]

      scenario_data.merge('engine_dump' => engine_dump)
    end
  end

  def build_final_json_structure(manifest_data, combined_scenarios)
    result = manifest_data.merge('scenarios' => combined_scenarios)
    result.delete('saved_scenarios')
    result
  end

  def generate_filename
    date = Time.current.strftime('%Y%m%d%H%M')
    env = Rails.env.production? ? 'pro' : Rails.env
    "#{date}_#{env}.etm"
  end

  def cleanup_and_fail(error, result)
    Rails.logger.error("SavedScenarioPacker::Dump failed: #{error}")

    log_result_warnings(result)

    Failure("Failed to create dump: #{error}")
  end

  def log_result_warnings(result)
    return unless result.success? && result.value!.respond_to?(:warnings)

    result.value!.warnings.each { |warning| Rails.logger.warn(warning) }
  end
end
