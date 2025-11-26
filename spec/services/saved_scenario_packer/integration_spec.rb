# frozen_string_literal: true

require 'rails_helper'

describe 'SavedScenarioPacker Integration', type: :service do
  let(:version) { Version.find_or_create_by!(tag: 'latest') }
  let(:owner) { create(:user, name: 'John Doe', email: 'john@example.com') }
  let(:collaborator) { create(:user, name: 'Jane Smith', email: 'jane@example.com') }
  let(:viewer) { create(:user, name: 'Bob Jones', email: 'bob@example.com') }
  let(:admin) { create(:user, name: 'Admin User', email: 'admin@example.com') }

  let!(:saved_scenario_one) do
    create(:saved_scenario,
      title: 'Netherlands 2050',
      description: 'Test scenario for Netherlands',
      area_code: 'nl',
      end_year: 2050,
      scenario_id: 123,
      scenario_id_history: [120, 121, 122],
      version: version,
      private: false
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
      create(:saved_scenario_user, saved_scenario: ss, user: collaborator, role_id: User::Roles.index_of(:scenario_collaborator))
      create(:saved_scenario_user, saved_scenario: ss, user: viewer, role_id: User::Roles.index_of(:scenario_viewer))
    end
  end

  let!(:saved_scenario_two) do
    create(:saved_scenario,
      title: 'Germany 2040',
      description: 'Test scenario for Germany',
      area_code: 'de',
      end_year: 2040,
      scenario_id: 124,
      scenario_id_history: [],
      version: version,
      private: true
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
    end
  end

  let(:saved_scenario_ids) { [saved_scenario_one.id, saved_scenario_two.id] }

  # Mock HTTP client for both dump and load
  let(:http_client) { instance_double(Faraday::Connection) }

  let(:engine_dump_one) do
    {
      'area_code' => 'nl',
      'end_year' => 2050,
      'user_values' => { 'foo' => 100 },
      'metadata' => { 'id' => 123, 'title' => 'Netherlands 2050' }
    }
  end

  let(:engine_dump_two) do
    {
      'area_code' => 'de',
      'end_year' => 2040,
      'user_values' => { 'bar' => 200 },
      'metadata' => { 'id' => 124, 'title' => 'Germany 2040' }
    }
  end

  before do
    # Mock ETEngine streaming dump API call using streaming helper
    streaming_body = "#{engine_dump_one.to_json}\n#{engine_dump_two.to_json}\n"
    mock_streaming_response(http_client, '/api/v3/scenarios/stream', streaming_body)

    # Mock ETEngine load_dump API calls to return new scenario IDs
    allow(http_client).to receive(:post)
      .with('/api/v3/scenarios/load_dump', engine_dump_one)
      .and_return(instance_double(Faraday::Response, success?: true, body: { 'id' => 223 }, status: 200))

    allow(http_client).to receive(:post)
      .with('/api/v3/scenarios/load_dump', engine_dump_two)
      .and_return(instance_double(Faraday::Response, success?: true, body: { 'id' => 224 }, status: 200))
  end

  after do
    # Clean up any created ZIP files
    FileUtils.rm_rf(Rails.root.join('tmp', 'saved_scenario_dumps'))
  end

  describe 'full dump and load cycle' do
    it 'generates dump filenames following the current convention' do
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call

      expect(dump_result).to be_success

      basename = File.basename(dump_result.value!.file_path)
      count = saved_scenario_ids.size
      env_segment = Rails.env.production? ? 'pro' : Rails.env

      expect(basename).to match(/\A#{count}_scenarios_#{env_segment}_\d{8}\.etm\z/)
    end

    it 'successfully dumps and loads scenarios maintaining data integrity' do
      # Phase 1: Dump
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call

      expect(dump_result).to be_success
      dump_data = dump_result.value!

      expect(dump_data).to be_a(SavedScenarioPacker::Results::DumpResult)
      expect(dump_data.scenario_count).to eq(2)
      expect(File.exist?(dump_data.file_path)).to be true

      # Phase 2: Load into new scenarios
      load_service = SavedScenarioPacker::Load.new(dump_data.file_path, http_client, admin)
      load_result = load_service.call

      expect(load_result).to be_success
      load_data = load_result.value!

      expect(load_data).to be_a(SavedScenarioPacker::Results::LoadResult)
      expect(load_data.saved_scenarios.size).to eq(2)

      # Phase 3: Verify data integrity
      loaded_nl = load_data.saved_scenarios.find { |s| s.title == 'Netherlands 2050' }
      expect(loaded_nl.area_code).to eq('nl')
      expect(loaded_nl.end_year).to eq(2050)
      expect(loaded_nl.scenario_id).to eq(223)
      expect(loaded_nl.scenario_id_history).to include(120, 121, 122, 223)
      expect(loaded_nl.private).to be false

      loaded_de = load_data.saved_scenarios.find { |s| s.title == 'Germany 2040' }
      expect(loaded_de.area_code).to eq('de')
      expect(loaded_de.end_year).to eq(2040)
      expect(loaded_de.scenario_id).to eq(224)
      expect(loaded_de.scenario_id_history).to include(224)
      expect(loaded_de.private).to be true
    end

    it 'preserves user roles across dump and load' do
      # Dump
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call
      dump_data = dump_result.value!

      # Load
      load_service = SavedScenarioPacker::Load.new(dump_data.file_path, http_client, admin)
      load_result = load_service.call
      load_data = load_result.value!

      # Verify user assignments
      loaded_scenario = load_data.saved_scenarios.find { |s| s.title == 'Netherlands 2050' }

      expect(loaded_scenario.owners.map(&:user)).to include(owner)
      expect(loaded_scenario.collaborators.map(&:user)).to include(collaborator)
      expect(loaded_scenario.viewers.map(&:user)).to include(viewer)
    end

    it 'handles scenario updates correctly' do
      # First dump and load
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call
      dump_data = dump_result.value!

      load_service = SavedScenarioPacker::Load.new(dump_data.file_path, http_client, admin)
      load_result = load_service.call
      first_load = load_result.value!

      # Update the scenario and dump again
      saved_scenario_one.update!(scenario_id: 125, scenario_id_history: [120, 121, 122, 123])

      # Mock the new dump
      new_engine_dump = engine_dump_one.merge('metadata' => { 'id' => 125, 'title' => 'Netherlands 2050' })
      mock_streaming_response(http_client, '/api/v3/scenarios/stream', "#{new_engine_dump.to_json}\n")

      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', new_engine_dump)
        .and_return(instance_double(Faraday::Response, success?: true, body: { 'id' => 225 }, status: 200))

      # Second dump
      dump_service2 = SavedScenarioPacker::Dump.new([saved_scenario_one.id], http_client, owner)
      dump_result2 = dump_service2.call
      dump_data2 = dump_result2.value!

      # Load into the same saved_scenario record
      load_service2 = SavedScenarioPacker::Load.new(dump_data2.file_path, http_client, admin)
      load_result2 = load_service2.call
      second_load = load_result2.value!

      # Verify history was preserved and merged
      updated_scenario = second_load.saved_scenarios.first
      expect(updated_scenario.id).to eq(saved_scenario_one.id)
      expect(updated_scenario.scenario_id).to eq(225)
      # History should include: original history (120, 121, 122, 123) + new ID (225)
      # Note: 223 was only in the first_load's created scenarios, not in the original saved_scenario_one
      expect(updated_scenario.scenario_id_history).to include(120, 121, 122, 123, 225)
    end
  end

  describe 'error recovery in dump/load cycle' do
    it 'handles partial dump failures gracefully' do
      # Mock response with only one scenario (124 missing from stream)
      partial_streaming_body = "#{engine_dump_one.to_json}\n"
      mock_streaming_response(http_client, '/api/v3/scenarios/stream', partial_streaming_body)

      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call

      expect(dump_result).to be_success
      dump_data = dump_result.value!
      expect(dump_data.scenario_count).to eq(1)
      expect(dump_data.warnings).not_to be_empty

      # Load should work with partial data
      # Need to update the mock to only expect one load call
      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', engine_dump_one)
        .and_return(instance_double(Faraday::Response, success?: true, body: { 'id' => 223 }, status: 200))

      load_service = SavedScenarioPacker::Load.new(dump_data.file_path, http_client, admin)
      load_result = load_service.call

      expect(load_result).to be_success
      load_data = load_result.value!
      expect(load_data.saved_scenarios.size).to eq(1)
    end

    it 'handles partial load failures gracefully' do
      # Successful dump
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call
      dump_data = dump_result.value!

      # Make one scenario fail to load
      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', engine_dump_two)
        .and_return(instance_double(Faraday::Response, success?: false, status: 500))

      load_service = SavedScenarioPacker::Load.new(dump_data.file_path, http_client, admin)
      load_result = load_service.call

      expect(load_result).to be_success
      load_data = load_result.value!
      expect(load_data.saved_scenarios.size).to eq(1)
      expect(load_data.warnings).to include(match(/Failed to load scenario 124/))
    end
  end

  describe 'ETM file structure validation' do
    it 'includes correct metadata and scenarios' do
      dump_service = SavedScenarioPacker::Dump.new(saved_scenario_ids, http_client, owner)
      dump_result = dump_service.call
      file_path = dump_result.value!.file_path

      # Read and verify file structure
      data = extract_from_etm(file_path)

      expect(data[:version]).to eq('1.0')
      expect(data[:etm_version]).to eq('latest')
      expect(data[:scenarios].size).to eq(2)

      nl_scenario = data[:scenarios].find { |s| s[:title] == 'Netherlands 2050' }
      expect(nl_scenario[:scenario_id]).to eq(123)
      expect(nl_scenario[:scenario_id_history]).to eq([120, 121, 122])
      expect(nl_scenario[:area_code]).to eq('nl')
      expect(nl_scenario[:owner][:email]).to eq(owner.email)
      expect(nl_scenario[:collaborators].size).to eq(1)
      expect(nl_scenario[:viewers].size).to eq(1)
      expect(nl_scenario[:engine_dump]).to be_a(Hash)
      expect(nl_scenario[:engine_dump][:metadata][:id]).to eq(123)
    end
  end

  describe 'newline-delimited JSON handling in integration' do
    before do
      # Mock NDJSON streaming response from ETEngine
      mock_streaming_response(http_client, '/api/v3/scenarios/stream', "#{engine_dump_one.to_json}\n")

      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', engine_dump_one)
        .and_return(instance_double(
          Faraday::Response,
          success?: true,
          body: "{\"id\":223}\n",
          status: 200
        ))
    end

    it 'handles NDJSON throughout the full cycle' do
      dump_service = SavedScenarioPacker::Dump.new([saved_scenario_one.id], http_client, owner)
      dump_result = dump_service.call

      expect(dump_result).to be_success

      load_service = SavedScenarioPacker::Load.new(dump_result.value!.file_path, http_client, admin)
      load_result = load_service.call

      expect(load_result).to be_success
      expect(load_result.value!.saved_scenarios.first.scenario_id).to eq(223)
    end
  end
end
