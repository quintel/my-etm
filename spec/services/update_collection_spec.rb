# frozen_string_literal: true

require 'rails_helper'

describe UpdateCollection, type: :service do
  let(:user) { create(:user) }
  let(:collection) { create(:collection, user: user) }
  let!(:saved_scenario) do
    FactoryBot.create(:saved_scenario, user: user, id: 900)
  end
  let!(:saved_scenario17) { create(:saved_scenario,  user: user, id: 17) }
  let!(:saved_scenario18) { create(:saved_scenario,  user: user, id: 18) }

  let(:settings) do
    {
      title: 'My Updated Title',
      area_code: 'nl',
      end_year: 2050,
      scenario_ids: [ 101, 102 ],
      saved_scenario_ids: [ 17, 18 ]
    }
  end

  let(:result) { described_class.call(collection, user, settings) }

  before do
    allow_any_instance_of(SavedScenario).to receive(:viewer?).and_return(true)
    collection.scenarios.create!(scenario_id: 999)
    collection.collection_saved_scenarios.create!(saved_scenario_id: saved_scenario.id)
  end

  context 'when the settings are valid' do
    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is successful' do
      expect(result).to be_successful
    end

    it 'updates the title' do
      expect(result.value.title).to eq('My Updated Title')
    end

    it 'updates the area_code' do
      expect(result.value.area_code).to eq('nl')
    end

    it 'updates the end_year' do
      expect(result.value.end_year).to eq(2050)
    end

    it 'updates the scenario_ids on the collection' do
      expect { result }.to change { collection.scenarios.count }.from(3).to(2)
    end

    it 'sets the updated ids' do
      updated_ids = result.value.scenarios.pluck(:scenario_id)
      expect(updated_ids).to match_array([ 101, 102 ])
    end

    it 'updates the saved_scenario_ids on the collection' do
      expect { result }.to change { collection.collection_saved_scenarios.count }.from(1).to(2)
    end

    it 'sets the updated saved_scenario_ids' do
      updated_ids = result.value.collection_saved_scenarios.pluck(:saved_scenario_id)
      expect(updated_ids).to match_array([ 17, 18 ])
    end
  end

  context 'when the settings fail validation' do
    let(:settings) do
      {
        title: '',
        scenario_ids: [ -1, 0 ],
        saved_scenario_ids: [ 201 ]
      }
    end

    it 'returns a ServiceResult' do
      expect(result).to be_a(ServiceResult)
    end

    it 'is not successful' do
      expect(result).not_to be_successful
    end

    it 'does not change the collection title to nothing' do
      expect(collection.reload.title).not_to eq('')
    end

    it 'does not change the collection scenarios' do
      expect(collection.scenarios.pluck(:scenario_id)).to include(999)
    end
  end
end
