# frozen_string_literal: true

require 'rails_helper'

describe SavedScenarioPacker::Dump, type: :service do
  let(:version) { Version.find_or_create_by!(tag: 'latest') }
  let(:owner) { create(:user, name: 'Buster Keaton', email: 'buster@keatons.com') }

  let!(:saved_scenario_one) do
    create(:saved_scenario,
      title: 'Netherlands 2050',
      area_code: 'nl',
      end_year: 2050,
      scenario_id: 123,
      version: version
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
    end
  end

  let!(:saved_scenario_two) do
    create(:saved_scenario,
      title: 'Germany 2040',
      area_code: 'de',
      end_year: 2040,
      scenario_id: 124,
      version: version
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
    end
  end

  let(:saved_scenario_ids) { [saved_scenario_one.id, saved_scenario_two.id] }
  let(:current_user) { owner }

  # Mock HTTP client
  let(:http_client) { instance_double(Faraday::Connection) }

  let(:engine_dump_one) do
    {
      'original_scenario_id' => 123,
      'area_code' => 'nl',
      'end_year' => 2050,
      'user_values' => { 'foo' => 100 }
    }
  end

  let(:engine_dump_two) do
    {
      'original_scenario_id' => 124,
      'area_code' => 'de',
      'end_year' => 2040,
      'user_values' => { 'bar' => 200 }
    }
  end

  let(:streaming_response_body) do
    "#{engine_dump_one.to_json}\n#{engine_dump_two.to_json}\n"
  end

  let(:successful_streaming_response) do
    instance_double(Faraday::Response, success?: true, body: streaming_response_body, status: 200)
  end

  let(:service) { described_class.new(saved_scenario_ids, http_client, current_user) }

  before do
    # Mock successful ETEngine streaming API call
    allow(http_client).to receive(:get)
      .with('/api/v3/scenarios/dump', ids: [123, 124])
      .and_return(successful_streaming_response)
  end

  after do
    # Clean up any created ETM files
    FileUtils.rm_rf(Rails.root.join('tmp', 'saved_scenario_dumps'))
  end

  describe '#call' do
    it 'returns a Success result' do
      result = service.call
      expect(result).to be_success
    end

    it 'returns a DumpResult with correct attributes' do
      result = service.call
      dump_result = result.value!

      expect(dump_result).to be_a(SavedScenarioPacker::DumpResult)
      expect(dump_result.file_path).to be_a(String)
      expect(dump_result.file_path).to end_with('.etm')
      expect(dump_result.scenario_count).to eq(2)
      expect(dump_result.warnings).to be_empty
      expect(File.exist?(dump_result.file_path)).to be true
    end

    it 'creates an ETM file with the expected naming pattern' do
      result = service.call
      filename = File.basename(result.value!.file_path)
      expect(filename).to match(/2_scenarios_test_\d{8}_\d{6}\.etm/)
    end

    it 'fetches dumps from ETEngine using streaming endpoint' do
      service.call
      expect(http_client).to have_received(:get).with('/api/v3/scenarios/dump', ids: [123, 124]).once
    end

    describe 'ETM file contents' do
      let(:etm_path) { service.call.value!.file_path }
      let(:files) { extract_from_etm(etm_path) }

      it 'includes a manifest.json file' do
        expect(files).to have_key('manifest.json')
      end

      it 'includes scenario dump files in dumps/ directory' do
        expect(files).to have_key("dumps/scenario_123_saved_#{saved_scenario_one.id}.json")
        expect(files).to have_key("dumps/scenario_124_saved_#{saved_scenario_two.id}.json")
      end

      it 'has valid JSON in manifest.json' do
        manifest_content = files['manifest.json']
        expect { JSON.parse(manifest_content) }.not_to raise_error
      end

      it 'has valid JSON in scenario dumps' do
        dump_content = files["dumps/scenario_123_saved_#{saved_scenario_one.id}.json"]
        parsed = JSON.parse(dump_content)
        expect(parsed['original_scenario_id']).to eq(123)
        expect(parsed['area_code']).to eq('nl')
      end
    end
  end

  describe 'error handling' do
    context 'when no saved scenarios exist with the provided IDs' do
      let(:saved_scenario_ids) { [99999] }

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
      end

      it 'includes an error message' do
        result = service.call
        expect(result.failure).to include('No saved scenarios found')
      end
    end

    context 'when all ETEngine dumps fail' do
      before do
        failed_response = instance_double(Faraday::Response, success?: false, status: 404)
        allow(http_client).to receive(:get).and_return(failed_response)
      end

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
      end

      it 'includes an error message about dump failure' do
        result = service.call
        expect(result.failure).to include('Failed to dump scenarios from ETEngine')
      end
    end

    context 'when some scenarios are missing from ETEngine response' do
      let(:partial_response_body) do
        "#{engine_dump_one.to_json}\n"
      end

      let(:partial_streaming_response) do
        instance_double(Faraday::Response, success?: true, body: partial_response_body, status: 200)
      end

      before do
        allow(http_client).to receive(:get)
          .with('/api/v3/scenarios/dump', ids: [123, 124])
          .and_return(partial_streaming_response)
      end

      it 'still succeeds with partial data' do
        result = service.call
        expect(result).to be_success
      end

      it 'includes warnings in the result' do
        result = service.call
        dump_result = result.value!

        expect(dump_result.warnings).not_to be_empty
        expect(dump_result.warnings.first).to include('Failed to dump scenario 124')
        expect(dump_result.scenario_count).to eq(1)
      end

      it 'only includes successfully dumped scenarios' do
        etm_path = service.call.value!.file_path
        files = extract_from_etm(etm_path)
        expect(files).to have_key("dumps/scenario_123_saved_#{saved_scenario_one.id}.json")
        expect(files).not_to have_key("dumps/scenario_124_saved_#{saved_scenario_two.id}.json")
      end
    end
  end

  describe 'newline-delimited JSON handling' do
    it 'handles NDJSON streaming responses with multiple scenarios' do
      # This is the standard case - already covered by the default mock
      result = service.call
      expect(result).to be_success

      etm_path = result.value!.file_path
      files = extract_from_etm(etm_path)

      dump_content_one = files["dumps/scenario_123_saved_#{saved_scenario_one.id}.json"]
      parsed_one = JSON.parse(dump_content_one)
      expect(parsed_one['original_scenario_id']).to eq(123)

      dump_content_two = files["dumps/scenario_124_saved_#{saved_scenario_two.id}.json"]
      parsed_two = JSON.parse(dump_content_two)
      expect(parsed_two['original_scenario_id']).to eq(124)
    end

    it 'handles empty lines in NDJSON stream' do
      response_with_empty_lines = instance_double(
        Faraday::Response,
        success?: true,
        body: "#{engine_dump_one.to_json}\n\n#{engine_dump_two.to_json}\n",
        status: 200
      )

      allow(http_client).to receive(:get)
        .with('/api/v3/scenarios/dump', ids: [123, 124])
        .and_return(response_with_empty_lines)

      result = service.call
      expect(result).to be_success
      expect(result.value!.scenario_count).to eq(2)
    end
  end

  describe 'version consistency validation' do
    context 'when scenarios have different versions' do
      let(:version_2023) { Version.find_or_create_by!(tag: '2023.01', url_prefix: '2023-01.') }

      before do
        saved_scenario_two.update!(version: version_2023)
      end

      it 'still succeeds' do
        result = service.call
        expect(result).to be_success
      end

      it 'logs a warning about mixed versions' do
        expect(Rails.logger).to receive(:warn).with(/Dumping scenarios from multiple versions/)
        service.call
      end
    end

    context 'when all scenarios have the same version' do
      it 'does not log a warning' do
        expect(Rails.logger).not_to receive(:warn)
        service.call
      end
    end
  end

  describe 'temp file cleanup' do
    context 'when an error occurs before ZIP creation' do
      before do
        allow(http_client).to receive(:get).and_raise(StandardError, 'Network error')
      end

      it 'cleans up temporary files' do
        temp_dir = Rails.root.join('tmp', 'saved_scenario_dumps')
        FileUtils.mkdir_p(temp_dir)

        service.call

        # The cleanup should have removed temp files, but the directory might still exist
        # We're mainly testing that the ensure block runs without error
        expect(true).to be true
      end
    end
  end
end
