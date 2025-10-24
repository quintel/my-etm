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
        myc.reload
      end

      it 'returns the scenario ids' do
        expect(myc.latest_scenario_ids).to include(111)
      end
    end
  end

  describe 'number of scenarios' do
    let(:user) { create(:user) }
    let(:myc) { create(:collection, user: user, scenarios_count: 7) }

    context 'with more than 6 combined scenarios' do
      before do
        saved_scenario = create(:saved_scenario, scenario_id: 111, user: user)
        create(:collection_saved_scenario, collection: myc, saved_scenario: saved_scenario)
      end

      it 'is not valid' do
        expect(myc).not_to be_valid
      end
    end
  end

  describe 'scenario versions' do
    let(:user) { create(:user) }

    let(:version) { create(:version) }
    let(:version_1) { create(:version) }

    # We don't validate to be able to stub the versions
    let(:scenario1) do
       s = build(:saved_scenario, version: version, user: user)
       s.save(validate: false)

       s
    end
    let(:scenario2) do
      s = build(:saved_scenario, version: version_1, user: user, scenario_id: 99)
      s.save(validate: false)

      s
    end

    context 'when all scenarios belong to the same version' do
      let(:collection) { create(:collection, interpolation: false, user: user, version: version) }

      before do
        create(:saved_scenario_user, saved_scenario: scenario1, user: user)
        create(:collection_saved_scenario, saved_scenario: scenario1, collection: collection)

        collection.reload
      end

      it 'is valid' do
        expect(collection).to be_valid
      end
    end

    context 'when scenarios belong to different versions' do
      let(:collection) { create(:collection, user: user, version: version) }

      before do
        create(:saved_scenario_user, saved_scenario: scenario1, user: user)
        create(:saved_scenario_user, saved_scenario: scenario2, user: user)
        create(:collection_saved_scenario, saved_scenario: scenario1, collection: collection)
        create(:collection_saved_scenario, saved_scenario: scenario2, collection: collection)

        collection.reload
      end

      it 'is not valid' do
        expect(collection).not_to be_valid
      end
    end
  end

  describe '.saved_scenario_ids=' do
    let(:user) { create(:user) }

    let(:ss1) { create(:saved_scenario, user: user) }
    let(:ss2) { create(:saved_scenario, user: user) }
    let(:ss3) { create(:saved_scenario, user: user) }

    let(:collection) { create(:collection, interpolation: false, user: user, scenarios_count: 0) }

    before do
      # They are unordered at this moment, but will show as [1, 2, 3]
      collection.saved_scenarios << ss1
      collection.saved_scenarios << ss2
      collection.saved_scenarios << ss3
    end

    context 'when changing the existing order' do
      subject do
        collection.update(saved_scenario_ids: [ss3.id, ss2.id, ss1.id])
      end

      it 'changes the latest_scenario_ids order' do
        expect { subject }.to change { collection.reload.saved_scenario_ids }
          .from([ss1.id, ss2.id, ss3.id])
          .to([ss3.id, ss2.id, ss1.id])
      end

      it 'keeps the saved scenarios' do
        before_ids = collection.saved_scenario_ids
        subject
        expect(collection.reload.saved_scenario_ids).to match_array(before_ids)
      end
    end

    context 'when inserting a saved scenario in the order' do
      let(:ss4) { create(:saved_scenario, user: user) }

      subject do
        collection.update(saved_scenario_ids: [ss1.id, ss4.id, ss2.id, ss3.id])
      end

      it 'changes the saved_scenario_ids order' do
        expect { subject }.to change { collection.reload.saved_scenario_ids }
          .from([ss1.id, ss2.id, ss3.id])
          .to([ss1.id, ss4.id, ss2.id, ss3.id])
      end

      it 'adds the new saved scenario' do
        expect { subject }.to change { collection.reload.saved_scenario_ids.include?(ss4.id) }
          .from(false).to(true)
      end
    end

    context 'when inserting a saved scenario in the order that is inaccesible by the user' do
      let(:other_user) { create(:user) }
      let(:ss4) { create(:saved_scenario, user: other_user) }

      subject do
        collection.update(saved_scenario_ids: [ss1.id, ss4.id, ss2.id, ss3.id])
      end

      it 'does not change the latest_scenario_ids order' do
        expect { subject }.not_to change { collection.reload.saved_scenario_ids }
      end

      it 'does not add the extra saved scenario' do
        expect { subject }.not_to change { collection.reload.saved_scenario_ids.include?(ss4.id) }
      end
    end

    context 'when removing a scenario from the order' do
      subject do
        collection.update(saved_scenario_ids: [ss1.id, ss3.id])
      end

      it 'changes the saved_scenario_ids order' do
        expect { subject }.to change { collection.reload.saved_scenario_ids }
          .from([ss1.id, ss2.id, ss3.id])
          .to([ss1.id, ss3.id])
      end

      it 'removes the saved scenario' do
        expect { subject }.to change { collection.reload.saved_scenario_ids.include?(ss2.id) }
          .from(true).to(false)
      end
    end

    context 'when attempting to update an interpolated collection' do
      let(:interp_coll) { create(:collection, interpolation: true, user: user, scenarios_count: 0) }

      subject do
        interp_coll.update(saved_scenario_ids: [ss1.id, ss3.id])
      end

      it 'does not insert a saved_scenario' do
        expect { subject }.not_to change { interp_coll.reload.saved_scenario_ids }
      end

      it 'keeps the scenarios' do
        expect { subject }.not_to change { interp_coll.saved_scenario_ids }
      end
    end

    context 'when trying to insert too many saved scenarios' do
      let(:many_ss) { Array.new(5) { create(:saved_scenario, user: user) } }

      subject do
        collection.update(saved_scenario_ids: [ss1.id, ss2.id, ss3.id, *many_ss.map(&:id)])
      end

      it 'does not change the saved_scenario_ids order' do
        expect { subject }.not_to change { collection.reload.saved_scenario_ids }
      end
    end

    context 'when removing all saved scenarios' do
      subject do
        collection.update(saved_scenario_ids: [])
      end

      it 'nothing changes' do
        expect { subject }.not_to change { collection.reload.saved_scenario_ids }
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
