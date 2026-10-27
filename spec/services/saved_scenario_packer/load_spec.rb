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
    allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([]))
    allow(SavedScenario::PerformEngineCallbacks).to receive(:call).and_return(ServiceResult.success)

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
      expect(load_result.failures).to be_empty
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

    it 'starts each loaded scenario with an empty history' do
      result = service.call
      scenario = result.value!.saved_scenarios.find { |s| s.title == 'Netherlands 2050' }

      expect(scenario.scenario_id_history).to be_empty
    end

    it 'gives each loaded scenario to the loading user only' do
      scenario = service.call.value!.saved_scenarios.first

      expect(scenario.saved_scenario_users.map(&:user)).to eq([ admin_user ])
      expect(scenario.owners.first.user).to eq(admin_user)
    end

    it 'runs the ETEngine callbacks for each loaded scenario' do
      service.call

      expect(SavedScenario::PerformEngineCallbacks).to have_received(:call)
        .with(http_client, 223, saved_scenario: an_instance_of(SavedScenario))
      expect(SavedScenario::PerformEngineCallbacks).to have_received(:call)
        .with(http_client, 224, saved_scenario: an_instance_of(SavedScenario))
    end

    it 'keeps the scenario and warns when the ETEngine callbacks fail' do
      allow(SavedScenario::PerformEngineCallbacks).to receive(:call).and_raise(StandardError, 'Engine down')
      result = service.call.value!

      expect(result.saved_scenarios.size).to eq(2)
      expect(result.warnings).to include(match(/ETEngine callbacks failed for Netherlands 2050/))
    end

    it 'binds each loaded Session' do
      service.call

      expect(ApiScenario::SetBound).to have_received(:call).with(admin_user, version, [ 223 ], true)
    end

    it 'unbinds the loaded Session when the scenario cannot be saved' do
      allow(SavedScenario).to receive(:create!).and_raise(ActiveRecord::RecordNotSaved, 'nope')
      service.call

      expect(ApiScenario::SetBound).to have_received(:call).with(admin_user, version, [ 223 ], false)
    end

    it 'saves nothing when ETEngine fails to bind the loaded Sessions' do
      allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.failure('Engine down'))

      expect { service.call }.not_to change(SavedScenario, :count)
    end

    context 'when a local scenario has the same id as a dumped one' do
      let!(:existing_scenario) do
        create(:saved_scenario,
          id: 100,
          scenario_id: 999,
          scenario_id_history: [997, 998],
          title: 'Unrelated local scenario',
          version: version
        )
      end

      it 'creates a new scenario for every dumped one' do
        expect { service.call }.to change(SavedScenario, :count).by(2)
      end

      it 'leaves the local scenario untouched' do
        service.call

        expect(existing_scenario.reload).to have_attributes(
          title: 'Unrelated local scenario', scenario_id: 999, scenario_id_history: [997, 998]
        )
      end
    end

    context 'when loading onto a given version' do
      let(:stable) { Version.find_by!(tag: 'stable.01') }
      let(:service) { described_class.new(file_path.to_s, http_client, admin_user, version: stable) }

      it 'binds and records the scenarios on that version' do
        scenario = service.call.value!.saved_scenarios.first

        expect(scenario.version).to eq(stable)
        expect(ApiScenario::SetBound).to have_received(:call).with(admin_user, stable, [ 223 ], true)
      end
    end

    context 'when a dumped scenario was on another version' do
      before do
        combined_data = manifest_data.dup
        combined_data[:scenarios] = combined_data.delete(:saved_scenarios).map.with_index do |scenario, index|
          scenario.merge(version_tag: 'stable.01', engine_dump: index == 0 ? dump_data_one : dump_data_two)
        end
        create_etm_file(file_path, combined_data)
      end

      it 'records it on the default version' do
        scenario = service.call.value!.saved_scenarios.first

        expect(scenario.version).to eq(Version.default)
      end

      it 'warns that the version changed' do
        warnings = service.call.value!.warnings

        expect(warnings).to include('Netherlands 2050 was on version stable.01, loaded onto latest')
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

      it 'reports the failed scenarios' do
        result = service.call
        load_result = result.value!

        expect(load_result.failures).not_to be_empty
        expect(load_result.failures.first).to include('Failed to load scenario 124')
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

      it 'reports the failed scenario' do
        result = service.call
        expect(result.value!.failures).to include(match(/Engine dump not found for scenario 124/))
      end
    end
  end

  describe 'identities in the dump' do
    let(:manifest_data) do
      {
        source_environment: 'production',
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
            private: true,
            version_tag: 'latest',
            owner: { email: 'nonexistent@example.com', name: 'Ghost', role: 'owner' },
            collaborators: [{ email: collab_user.email, name: collab_user.name, role: 'collaborator' }],
            viewers: [{ email: 'viewer@example.com', name: 'Ghost viewer', role: 'viewer' }]
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

    it 'are ignored in favour of the loading user' do
      scenario = service.call.value!.saved_scenarios.first

      expect(scenario.saved_scenario_users.map(&:user)).to eq([ admin_user ])
    end

    it 'never create pending users' do
      expect { service.call }.not_to change { SavedScenarioUser.where(user_id: nil).count }
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
