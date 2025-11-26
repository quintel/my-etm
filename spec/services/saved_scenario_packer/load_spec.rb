# frozen_string_literal: true

require 'rails_helper'

describe SavedScenarioPacker::Load, type: :service do
  let(:version) { Version.find_or_create_by!(tag: 'latest') }
  let(:admin_user) { create(:user, name: 'Admin User', email: 'admin@example.com') }
  let(:owner_user) { create(:user, name: 'John Doe', email: 'john@example.com') }
  let(:collab_user) { create(:user, name: 'Jane Smith', email: 'jane@example.com') }

  let(:http_client) { instance_double(Faraday::Connection) }
  let(:file_path) { Rails.root.join('tmp', '2_scenarios_test_20240101_120000.etm') }

  let(:manifest_data) do
    {
      version: '1.0',
      source_environment: 'test',
      created_at: Time.current.iso8601,
      etm_version: 'latest',
      saved_scenarios: [
        {
          saved_scenario_id: 100,
          scenario_id: 123,
          scenario_id_history: [120, 121, 122],
          title: 'Netherlands 2050',
          description: 'Test scenario',
          area_code: 'nl',
          end_year: 2050,
          private: false,
          version_tag: 'latest',
          owner: { email: owner_user.email, name: owner_user.name, role: 'owner' },
          collaborators: [{ email: collab_user.email, name: collab_user.name, role: 'collaborator' }],
          viewers: [],
          created_at: 1.day.ago.iso8601,
          updated_at: 1.hour.ago.iso8601
        },
        {
          saved_scenario_id: 101,
          scenario_id: 124,
          scenario_id_history: [],
          title: 'Germany 2040',
          description: 'Another test',
          area_code: 'de',
          end_year: 2040,
          private: true,
          version_tag: 'latest',
          owner: { email: owner_user.email, name: owner_user.name, role: 'owner' },
          collaborators: [],
          viewers: [],
          created_at: 2.days.ago.iso8601,
          updated_at: 2.hours.ago.iso8601
        }
      ]
    }
  end

  let(:dump_data_one) do
    {
      'original_scenario_id' => 123,
      'area_code' => 'nl',
      'end_year' => 2050,
      'user_values' => { 'foo' => 100 }
    }
  end

  let(:dump_data_two) do
    {
      'original_scenario_id' => 124,
      'area_code' => 'de',
      'end_year' => 2040,
      'user_values' => { 'bar' => 200 }
    }
  end

  let(:load_response_one) do
    instance_double(Faraday::Response, success?: true, body: { 'id' => 223 }, status: 200)
  end

  let(:load_response_two) do
    instance_double(Faraday::Response, success?: true, body: { 'id' => 224 }, status: 200)
  end

  before do
    # Create a test ETM file with combined structure
    FileUtils.mkdir_p(File.dirname(file_path))

    # Combine manifest data with engine dumps
    combined_data = manifest_data.dup
    combined_data[:scenarios] = combined_data.delete(:saved_scenarios).map.with_index do |scenario, index|
      scenario.merge(engine_dump: index == 0 ? dump_data_one : dump_data_two)
    end

    create_etm_file(file_path, combined_data)

    # Mock ETEngine load_dump API calls
    allow(http_client).to receive(:post)
      .with('/api/v3/scenarios/load_dump', dump_data_one)
      .and_return(load_response_one)

    allow(http_client).to receive(:post)
      .with('/api/v3/scenarios/load_dump', dump_data_two)
      .and_return(load_response_two)
  end

  after do
    FileUtils.rm_f(file_path)
  end

  let(:service) { described_class.new(file_path.to_s, http_client, admin_user) }

  describe '#call' do
    it 'returns a Success result' do
      result = service.call
      expect(result).to be_success
    end

    it 'returns a LoadResult with correct attributes' do
      result = service.call
      load_result = result.value!

      expect(load_result).to be_a(SavedScenarioPacker::Results::LoadResult)
      expect(load_result.saved_scenarios).to be_an(Array)
      expect(load_result.saved_scenarios.size).to eq(2)
      expect(load_result.scenario_mappings).to be_an(Array)
      expect(load_result.scenario_mappings.size).to eq(2)
      expect(load_result.warnings).to be_empty
    end

    it 'creates new SavedScenario records' do
      expect { service.call }.to change(SavedScenario, :count).by(2)
    end

    it 'loads scenarios to ETEngine' do
      service.call
      expect(http_client).to have_received(:post).with('/api/v3/scenarios/load_dump', dump_data_one)
      expect(http_client).to have_received(:post).with('/api/v3/scenarios/load_dump', dump_data_two)
    end

    it 'creates scenarios with correct attributes' do
      result = service.call
      scenarios = result.value!.saved_scenarios

      first = scenarios.find { |s| s.title == 'Netherlands 2050' }
      expect(first.scenario_id).to eq(223)
      expect(first.area_code).to eq('nl')
      expect(first.end_year).to eq(2050)
      expect(first.private).to be false

      second = scenarios.find { |s| s.title == 'Germany 2040' }
      expect(second.scenario_id).to eq(224)
      expect(second.area_code).to eq('de')
      expect(second.end_year).to eq(2040)
      expect(second.private).to be true
    end

    it 'preserves scenario history from the dump' do
      result = service.call
      scenario = result.value!.saved_scenarios.find { |s| s.title == 'Netherlands 2050' }

      expect(scenario.scenario_id_history).to include(120, 121, 122, 223)
    end

    it 'assigns users correctly' do
      result = service.call
      scenario = result.value!.saved_scenarios.first

      expect(scenario.owners.first.user).to eq(owner_user)
      expect(scenario.collaborators.first.user).to eq(collab_user)
    end

    context 'when updating existing scenarios' do
      let!(:existing_scenario) do
        create(:saved_scenario,
          id: 100,
          scenario_id: 999,
          scenario_id_history: [997, 998],
          title: 'Old Title',
          version: version
        )
      end

      it 'updates the existing scenario' do
        expect { service.call }.to change(SavedScenario, :count).by(1) # Only creates the second one
      end

      it 'preserves and merges scenario history' do
        result = service.call
        updated = SavedScenario.find(100)

        # Should contain: old history + dump history + new ID
        expect(updated.scenario_id_history).to include(997, 998, 120, 121, 122, 223)
        expect(updated.scenario_id).to eq(223)
      end
    end
  end

  describe 'error handling' do
    context 'when ETM file does not exist' do
      before do
        FileUtils.rm_f(file_path)
      end

      let(:file_path) { Rails.root.join('tmp', 'nonexistent.etm') }

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
      end

      it 'includes an error message' do
        result = service.call
        expect(result.failure).to include('File not found')
      end
    end

    context 'when file is not an ETM file' do
      before do
        File.write(file_path.to_s.sub('.etm', '.txt'), 'not an etm file')
      end

      let(:file_path) { Rails.root.join('tmp', 'test_dump.txt') }

      after do
        FileUtils.rm_f(file_path)
      end

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
        expect(result.failure).to include('not an ETM file')
      end
    end

    context 'when scenarios data is missing' do
      let(:file_path_no_scenarios) { Rails.root.join('tmp', 'test_dump_no_scenarios.etm') }
      let(:service) { described_class.new(file_path_no_scenarios.to_s, http_client, admin_user) }

      before do
        # Create ETM file with no scenarios array
        create_etm_file(file_path_no_scenarios, {
          version: '1.0',
          etm_version: 'latest'
        })
      end

      after do
        FileUtils.rm_f(file_path_no_scenarios)
      end

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
        expect(result.failure).to include('No scenarios could be loaded')
      end
    end

    context 'when all ETEngine loads fail' do
      before do
        failed_response = instance_double(Faraday::Response, success?: false, status: 500)
        allow(http_client).to receive(:post).and_return(failed_response)
      end

      it 'returns a Failure result' do
        result = service.call
        expect(result).to be_failure
        expect(result.failure).to include('No scenarios could be loaded')
      end
    end

    context 'when some ETEngine loads fail' do
      before do
        failed_response = instance_double(Faraday::Response, success?: false, status: 500)
        allow(http_client).to receive(:post)
          .with('/api/v3/scenarios/load_dump', dump_data_one)
          .and_return(load_response_one)
        allow(http_client).to receive(:post)
          .with('/api/v3/scenarios/load_dump', dump_data_two)
          .and_return(failed_response)
      end

      it 'still succeeds with partial data' do
        result = service.call
        expect(result).to be_success
      end

      it 'includes warnings for failed scenarios' do
        result = service.call
        load_result = result.value!

        expect(load_result.warnings).not_to be_empty
        expect(load_result.warnings.first).to include('Failed to load scenario 124')
        expect(load_result.saved_scenarios.size).to eq(1)
      end

      it 'logs warnings' do
        expect(Rails.logger).to receive(:warn).with(/Load warning:.*Failed to load scenario 124/)
        service.call
      end
    end

    context 'when engine dump is missing for a scenario' do
      let(:file_path_partial) { Rails.root.join('tmp', 'test_dump_partial.etm') }
      let(:service) { described_class.new(file_path_partial.to_s, http_client, admin_user) }

      before do
        # Create ETM with scenarios but second one missing engine_dump
        partial_data = manifest_data.dup
        partial_data[:scenarios] = partial_data.delete(:saved_scenarios).map.with_index do |scenario, index|
          if index == 0
            scenario.merge(engine_dump: dump_data_one)
          else
            scenario # No engine_dump for second scenario
          end
        end

        create_etm_file(file_path_partial, partial_data)
      end

      after do
        FileUtils.rm_f(file_path_partial)
      end

      it 'still succeeds with partial data' do
        result = service.call
        expect(result).to be_success
        expect(result.value!.saved_scenarios.size).to eq(1)
      end

      it 'includes warnings' do
        result = service.call
        expect(result.value!.warnings).to include(match(/Engine dump not found for scenario 124/))
      end
    end
  end

  describe 'user assignment edge cases' do
    context 'when owner user does not exist' do
      let(:manifest_data) do
        {
          version: '1.0',
          source_environment: 'test',
          created_at: Time.current.iso8601,
          etm_version: 'latest',
          saved_scenarios: [
            {
              saved_scenario_id: 100,
              scenario_id: 123,
              scenario_id_history: [],
              title: 'Test Scenario',
              description: 'Test',
              area_code: 'nl',
              end_year: 2050,
              private: false,
              version_tag: 'latest',
              owner: { email: 'nonexistent@example.com', name: 'Ghost', role: 'owner' },
              collaborators: [],
              viewers: [],
              created_at: 1.day.ago.iso8601,
              updated_at: 1.hour.ago.iso8601
            }
          ]
        }
      end

      before do
        combined_data = manifest_data.dup
        combined_data[:scenarios] = combined_data.delete(:saved_scenarios).map do |scenario|
          scenario.merge(engine_dump: dump_data_one)
        end
        create_etm_file(file_path, combined_data)
      end

      it 'falls back to admin user' do
        result = service.call
        scenario = result.value!.saved_scenarios.first

        expect(scenario.owners.first.user).to eq(admin_user)
      end

      it 'includes a warning' do
        expect(Rails.logger).to receive(:warn).with(/Owner not found.*nonexistent@example.com/)
        service.call
      end
    end

    context 'when collaborator user does not exist' do
      let(:manifest_data) do
        {
          version: '1.0',
          source_environment: 'test',
          created_at: Time.current.iso8601,
          etm_version: 'latest',
          saved_scenarios: [
            {
              saved_scenario_id: 100,
              scenario_id: 123,
              scenario_id_history: [],
              title: 'Test Scenario',
              description: 'Test',
              area_code: 'nl',
              end_year: 2050,
              private: false,
              version_tag: 'latest',
              owner: { email: owner_user.email, name: owner_user.name, role: 'owner' },
              collaborators: [
                { email: 'nonexistent@example.com', name: 'Ghost', role: 'collaborator' }
              ],
              viewers: [],
              created_at: 1.day.ago.iso8601,
              updated_at: 1.hour.ago.iso8601
            }
          ]
        }
      end

      before do
        combined_data = manifest_data.dup
        combined_data[:scenarios] = combined_data.delete(:saved_scenarios).map do |scenario|
          scenario.merge(engine_dump: dump_data_one)
        end
        create_etm_file(file_path, combined_data)
      end

      it 'skips the nonexistent collaborator' do
        result = service.call
        scenario = result.value!.saved_scenarios.first

        expect(scenario.collaborators).to be_empty
      end

      it 'includes a warning' do
        expect(Rails.logger).to receive(:warn).with(/Collaborator not found.*nonexistent@example.com/)
        service.call
      end
    end
  end

  describe 'newline-delimited JSON handling' do
    let(:ndjson_load_response) do
      instance_double(
        Faraday::Response,
        success?: true,
        body: "{\"id\":223}\n",
        status: 200
      )
    end

    let(:multi_ndjson_load_response) do
      instance_double(
        Faraday::Response,
        success?: true,
        body: "{\"part1\":\"value1\"}\n{\"id\":224,\"part2\":\"value2\"}\n",
        status: 200
      )
    end

    it 'handles single-line NDJSON responses' do
      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', dump_data_one)
        .and_return(ndjson_load_response)

      result = service.call
      expect(result).to be_success

      scenario = result.value!.saved_scenarios.find { |s| s.title == 'Netherlands 2050' }
      expect(scenario.scenario_id).to eq(223)
    end

    it 'handles multi-line NDJSON responses by merging objects' do
      allow(http_client).to receive(:post)
        .with('/api/v3/scenarios/load_dump', dump_data_two)
        .and_return(multi_ndjson_load_response)

      result = service.call
      expect(result).to be_success

      scenario = result.value!.saved_scenarios.find { |s| s.title == 'Germany 2040' }
      expect(scenario.scenario_id).to eq(224)
    end

    it 'handles Hash responses (backward compatibility)' do
      result = service.call
      expect(result).to be_success
    end
  end
end
