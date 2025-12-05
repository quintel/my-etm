# frozen_string_literal: true

require 'rails_helper'

describe SavedScenarioPacker::Manifest, type: :service do
  let(:version) { Version.find_or_create_by!(tag: 'latest') }
  let(:owner) { create(:user, name: 'John Doe', email: 'john@example.com') }
  let(:collaborator) { create(:user, name: 'Jane Smith', email: 'jane@example.com') }
  let(:viewer) { create(:user, name: 'Bob Johnson', email: 'bob@example.com') }

  let!(:saved_scenario_one) do
    create(:saved_scenario,
      title: 'Netherlands 2050',
      area_code: 'nl',
      end_year: 2050,
      scenario_id: 123,
      scenario_id_history: [100, 110],
      private: false,
      version: version
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
      create(:saved_scenario_user, saved_scenario: ss, user: collaborator, role_id: User::Roles.index_of(:scenario_collaborator))
    end
  end

  let!(:saved_scenario_two) do
    create(:saved_scenario,
      title: 'Germany 2040',
      area_code: 'de',
      end_year: 2040,
      scenario_id: 124,
      private: true,
      version: version
    ).tap do |ss|
      create(:saved_scenario_user, saved_scenario: ss, user: owner, role_id: User::Roles.index_of(:scenario_owner))
      create(:saved_scenario_user, saved_scenario: ss, user: viewer, role_id: User::Roles.index_of(:scenario_viewer))
    end
  end

  let(:saved_scenarios) { [saved_scenario_one, saved_scenario_two] }
  let(:manifest) { described_class.new(saved_scenarios) }

  describe '#as_json' do
    let(:result) { manifest.as_json }

    it 'includes source environment' do
      expect(result[:source_environment]).to eq('test')
    end

    it 'includes created_at timestamp' do
      expect(result[:created_at]).to be_present
      expect { Time.iso8601(result[:created_at]) }.not_to raise_error
    end

    it 'includes ETM version' do
      expect(result[:etm_version]).to eq('latest')
    end

    it 'includes saved scenarios array' do
      expect(result[:saved_scenarios]).to be_an(Array)
      expect(result[:saved_scenarios].length).to eq(2)
    end

    describe 'saved scenario data' do
      let(:first_scenario) { result[:saved_scenarios].first }

      it 'includes saved_scenario_id' do
        expect(first_scenario[:saved_scenario_id]).to eq(saved_scenario_one.id)
      end

      it 'includes scenario_id' do
        expect(first_scenario[:scenario_id]).to eq(123)
      end

      it 'includes scenario_id_history' do
        expect(first_scenario[:scenario_id_history]).to eq([100, 110])
      end

      it 'includes title' do
        expect(first_scenario[:title]).to eq('Netherlands 2050')
      end

      it 'includes description' do
        expect(first_scenario[:description]).to be_a(String)
      end

      it 'includes area_code' do
        expect(first_scenario[:area_code]).to eq('nl')
      end

      it 'includes end_year' do
        expect(first_scenario[:end_year]).to eq(2050)
      end

      it 'includes private flag' do
        expect(first_scenario[:private]).to eq(false)
      end

      it 'includes version_tag' do
        expect(first_scenario[:version_tag]).to eq('latest')
      end

      it 'includes owner data' do
        expect(first_scenario[:owner]).to be_a(Hash)
        expect(first_scenario[:owner][:email]).to eq('john@example.com')
        expect(first_scenario[:owner][:name]).to eq('John Doe')
        expect(first_scenario[:owner][:role]).to eq('owner')
      end

      it 'includes collaborators' do
        expect(first_scenario[:collaborators]).to be_an(Array)
        expect(first_scenario[:collaborators].length).to eq(1)
        expect(first_scenario[:collaborators].first[:email]).to eq('jane@example.com')
        expect(first_scenario[:collaborators].first[:role]).to eq('collaborator')
      end

      it 'includes viewers' do
        second_scenario = result[:saved_scenarios].last
        expect(second_scenario[:viewers]).to be_an(Array)
        expect(second_scenario[:viewers].length).to eq(1)
        expect(second_scenario[:viewers].first[:email]).to eq('bob@example.com')
        expect(second_scenario[:viewers].first[:role]).to eq('viewer')
      end

      it 'includes timestamps' do
        expect(first_scenario[:created_at]).to be_present
        expect(first_scenario[:updated_at]).to be_present
        expect { Time.iso8601(first_scenario[:created_at]) }.not_to raise_error
      end
    end
  end

  describe '#to_json' do
    it 'returns a JSON string' do
      result = manifest.to_json
      expect(result).to be_a(String)
      expect { JSON.parse(result) }.not_to raise_error
    end

    it 'is pretty-printed' do
      result = manifest.to_json
      expect(result).to include("\n")
    end
  end

  # Note: Version tag handling for edge cases (mixed versions, no version) is tested in integration

  describe 'custom source environment' do
    let(:manifest) { described_class.new(saved_scenarios, 'production') }

    it 'uses the provided environment' do
      result = manifest.as_json
      expect(result[:source_environment]).to eq('production')
    end
  end

  describe 'pending users' do
    let!(:saved_scenario_with_pending) do
      create(:saved_scenario,
        title: 'Scenario with Pending Users',
        area_code: 'nl',
        end_year: 2050,
        scenario_id: 125,
        version: version
      ).tap do |ss|
        SavedScenarioUser.create!(
          saved_scenario: ss,
          user_email: 'pending.owner@example.com',
          role_id: User::Roles.index_of(:scenario_owner)
        )
        SavedScenarioUser.create!(
          saved_scenario: ss,
          user_email: 'pending.collab@example.com',
          role_id: User::Roles.index_of(:scenario_collaborator)
        )
        SavedScenarioUser.create!(
          saved_scenario: ss,
          user_email: 'pending.viewer@example.com',
          role_id: User::Roles.index_of(:scenario_viewer)
        )
      end
    end

    let(:saved_scenarios) { [saved_scenario_with_pending] }
    let(:result) { manifest.as_json }
    let(:scenario_data) { result[:saved_scenarios].first }

    it 'includes pending owner email' do
      expect(scenario_data[:owner]).to be_a(Hash)
      expect(scenario_data[:owner][:email]).to eq('pending.owner@example.com')
      expect(scenario_data[:owner][:name]).to be_nil
      expect(scenario_data[:owner][:role]).to eq('owner')
    end

    it 'includes pending collaborator email' do
      expect(scenario_data[:collaborators]).to be_an(Array)
      expect(scenario_data[:collaborators].length).to eq(1)
      expect(scenario_data[:collaborators].first[:email]).to eq('pending.collab@example.com')
      expect(scenario_data[:collaborators].first[:name]).to be_nil
      expect(scenario_data[:collaborators].first[:role]).to eq('collaborator')
    end

    it 'includes pending viewer email' do
      expect(scenario_data[:viewers]).to be_an(Array)
      expect(scenario_data[:viewers].length).to eq(1)
      expect(scenario_data[:viewers].first[:email]).to eq('pending.viewer@example.com')
      expect(scenario_data[:viewers].first[:name]).to be_nil
      expect(scenario_data[:viewers].first[:role]).to eq('viewer')
    end
  end
end
