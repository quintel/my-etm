# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Collection, type: :model do
  describe '.destroy_old_discarded!' do
    it 'does not destroy a myc which is not discarded' do
      myc = FactoryBot.create(:collection)

      expect { described_class.destroy_old_discarded! }
        .not_to change { described_class.exists?(myc.id) }
        .from(true)
    end

    it 'does not destroy a recently discarded myc' do
      myc = FactoryBot.create(:collection, discarded_at: Time.zone.now)

      expect { described_class.destroy_old_discarded! }
        .not_to change { described_class.exists?(myc.id) }
        .from(true)
    end

    it 'does not delete a discarded myc on the threshold of being old' do
      myc = FactoryBot.create(
        :collection,
        discarded_at: (Collection::AUTO_DELETES_AFTER - 10.seconds).ago
      )

      expect { described_class.destroy_old_discarded! }
        .not_to change { described_class.exists?(myc.id) }
        .from(true)
    end

    it 'destroys an old discarded myc' do
      myc = FactoryBot.create(
        :collection,
        discarded_at: (Collection::AUTO_DELETES_AFTER + 10.seconds).ago
      )

      expect { described_class.destroy_old_discarded! }
        .to change { described_class.exists?(myc.id) }
        .from(true).to(false)
    end
  end

  describe '#latest_scenario_ids' do
    let(:user) { create(:user) }
    let(:myc) { create(:collection, user: user) }

    context 'with only myc_scenarios' do
      it 'returns the scenario ids' do
        expect(myc.latest_scenario_ids).to include(myc.scenarios.first.scenario_id)
      end
    end

    context 'with myc_scenarios and saved scenarios' do
      before do
        saved_scenario = create(:saved_scenario, scenario_id: 111, user: user)
        create(:collection_saved_scenario, collection: myc, saved_scenario: saved_scenario)
      end

      it 'returns the scenairo ids' do
        expect(myc.latest_scenario_ids).to include(111)
      end
    end
  end

  describe 'number of scenarios' do
    let(:user) { create(:user) }
    let(:myc) { create(:collection, user: user, scenarios_count: 3) }

    context 'with more than 6 combined scenarios' do
      before do
        4.times do
          saved_scenario = create(:saved_scenario, scenario_id: 111, user: user)
          create(:collection_saved_scenario, collection: myc, saved_scenario: saved_scenario)
        end
      end

      it 'is not valid' do
        expect(myc).not_to be_valid
      end
    end
  end

  describe '#filter' do
    before { create(:collection, scenarios_count: 3, title: 'Hello', interpolation: false) }

    context 'when filtering on title' do
      context 'with a word that is contained in one of the titles' do
        subject { Collection.filter({ 'title' => 'ell' }) }

        it 'returns the collection' do
          expect(subject.count).to eq(1)
        end
      end

      context 'with a word that is not contained in one of the titles' do
        subject { Collection.filter({ 'title' => 'pp' }) }

        it 'returns the collection' do
          expect(subject.count).to eq(0)
        end
      end
    end
    context 'when filtering on interpolation' do
      before { create(:collection, scenarios_count: 2, interpolation: true) }
      context 'when false' do
        subject { Collection.filter({ 'plain'=> "1" }) }

        it 'returns one collection' do
          expect(subject.count).to eq(1)
        end
      end

      context 'when true' do
        subject { Collection.filter({ 'interpolated' => "1" }) }

        it 'returns one collection' do
          expect(subject.count).to eq(1)
        end
      end

      context 'when both' do
        subject { Collection.filter({ 'interpolated' => "1", 'plain'=> "1" }) }

        it 'returns both collections' do
          expect(subject.count).to eq(2)
        end
      end
    end
    context 'when filtering on both' do
      before { create(:collection, scenarios_count: 2, interpolation: true, title: 'ell') }
      context 'when interpolation is false and word in title' do
        subject { Collection.filter({ 'title' => 'ell', 'plain'=> "1" }) }

        it 'returns one collection' do
          expect(subject.count).to eq(1)
        end
      end
      context 'when interpolation is false and word in not title' do
        subject { Collection.filter({ 'title' => 'pp', 'plain'=> "1" }) }

        it 'returns no collection' do
          expect(subject.count).to eq(0)
        end
      end
      context 'when interpolation is true and word in title' do
        subject { Collection.filter({ 'title' => 'ell', 'interpolated' => "1" }) }

        it 'returns one collection' do
          expect(subject.count).to eq(1)
        end
      end
      context 'when interpolation is true and word in not title' do
        subject { Collection.filter({ 'title' => 'pp', 'interpolated' => "1" }) }

        it 'returns no collection' do
          expect(subject.count).to eq(0)
        end
      end
    end
  end
end
