# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::CreateCollection do
  let(:user) { create(:user) }
  let(:result) { described_class.new.call(user:, params:) }

  let(:params) do
    {
      title: 'My collection',
      area_code: 'nl2019',
      end_year: 2050,
      scenario_ids: [10, 20],
      version: Version.default.tag
    }
  end

  context 'with valid parameters' do
    it 'returns a success' do
      expect(result).to be_success
    end

    it 'returns the collection' do
      expect(result.value!).to be_a(Collection)
    end

    it 'creates a collection' do
      expect { result }.to change(Collection, :count).by(1)
    end

    it 'creates the scenarios for the collection' do
      expect(result.value!.scenarios.map(&:scenario_id)).to eq([10, 20])
    end
  end

  context 'with invalid parameters' do
    let(:params) do
      {}
    end

    it 'returns a failure' do
      expect(result).to be_failure
    end

    it 'returns the errors' do
      expect(result.failure).to eq({
        title: ['is missing'],
        scenario_ids: ['at least one scenario_id or saved_scenario_id should be present'],
        version: ["is missing"]
      })
    end
  end

  context 'with no scenario IDs' do
    let(:params) do
      super().merge(scenario_ids: [])
    end

    it 'returns a failure' do
      expect(result).to be_failure
    end

    it 'returns the errors' do
      expect(result.failure).to eq({
        scenario_ids: ['must be filled']
      })
    end
  end

  context 'with non-numeric scenario IDs' do
    let(:params) do
      super().merge(scenario_ids: [nil, 'nope', -1])
    end

    it 'returns a failure' do
      expect(result).to be_failure
    end

    it 'returns the errors' do
      expect(result.failure).to eq({
        scenario_ids: {
          0 => ['must be an integer'],
          1 => ['must be an integer'],
          2 => ['must be greater than 0']
        }
      })
    end
  end

  context 'when given more than 100 scenario IDs' do
    let(:params) do
      super().merge(scenario_ids: (1..101).to_a)
    end

    it 'returns a failure' do
      expect(result).to be_failure
    end

    it 'returns the errors' do
      expect(result.failure).to eq({
        scenario_ids: ['size cannot be greater than 100']
      })
    end
  end

  context 'with valid params, but duplicate scenario IDs' do
    let(:params) do
      super().merge(scenario_ids: [10, 10, 20])
    end

    it 'returns a success' do
      expect(result).to be_success
    end

    it 'creates the collection' do
      expect(result.value!).to be_a(Collection)
    end

    it 'creates the scenarios for the collection, ignoring duplicates' do
      expect(result.value!.scenarios.map(&:scenario_id).sort).to eq([10, 20])
    end
  end
end
