# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ScenarioGrant do
  describe '.for_role' do
    it 'grants write to a role that may write' do
      grant = described_class.for_role(scenario_id: 648_695, writable: true)

      expect(grant.level).to eq('write')
    end

    it 'grants read to a role that may not' do
      grant = described_class.for_role(scenario_id: 648_695, writable: false)

      expect(grant.level).to eq('read')
    end
  end

  describe '#as_claim' do
    it 'names the scenario id and the level' do
      grant = described_class.new(scenario_id: 648_695, level: 'write')

      expect(grant.as_claim).to eq('scenario_id' => 648_695, 'level' => 'write')
    end

    it 'carries the scenario id as an integer, whatever it was given' do
      grant = described_class.new(scenario_id: '648695', level: 'read')

      expect(grant.as_claim['scenario_id']).to eq(648_695)
    end
  end

  # Anything but "write" reads, so a malformed level can only lose access, never gain it.
  it 'falls back to read for an unrecognised level' do
    expect(described_class.new(scenario_id: 1, level: 'admin').level).to eq('read')
  end
end
