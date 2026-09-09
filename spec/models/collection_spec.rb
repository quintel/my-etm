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

  describe '#scenario_members_as_json' do
    let(:user) { create(:user) }
    let(:collection) { create(:collection, user:, scenarios_count: 1) }

    it 'pairs a saved scenario with its engine scenario' do
      saved_scenario = create(:saved_scenario, scenario_id: 111, title: 'Dutch net zero', user:)
      create(:collection_saved_scenario, collection:, saved_scenario:)

      expect(collection.reload.scenario_members_as_json).to include(
        {
          "saved_scenario_id" => saved_scenario.id,
          "scenario_id" => 111,
          "title" => 'Dutch net zero'
        }
      )
    end

    it 'has no saved scenario for a scenario the collection holds directly' do
      direct = collection.scenarios.first

      expect(collection.scenario_members_as_json).to include(
        { "saved_scenario_id" => nil, "scenario_id" => direct.scenario_id, "title" => nil }
      )
    end

    it 'lists the scenarios it holds directly before its saved scenarios' do
      direct = collection.scenarios.first
      saved_scenario = create(:saved_scenario, scenario_id: 111, user:)
      create(:collection_saved_scenario, collection:, saved_scenario:)

      expect(collection.reload.scenario_members_as_json.pluck("scenario_id"))
        .to eq([ direct.scenario_id, 111 ])
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

      it 'changes the saved_scenario_ids order' do
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

      it 'does not change the saved_scenario_ids order' do
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

    context 'when updating an interpolated collection' do
      subject do
        ss2030 = create(:saved_scenario, user: user, end_year: 2030, scenario_id: 11)
        ss2040 = create(:saved_scenario, user: user, end_year: 2040, scenario_id: 12)

        # ss1 ends in 2050
        interp_coll.update(saved_scenario_ids: [ ss1.id, ss2030.id, ss2040.id ])
      end

      let(:interp_coll) { create(:collection, interpolation: true, user: user, scenarios_count: 0) }

      it 'accepts one saved scenario per end year' do
        expect { subject }.to change { interp_coll.reload.saved_scenarios.count }.from(0).to(3)
      end

      it 'keeps the order it was given, rather than forcing it to be chronological' do
        subject

        expect(interp_coll.reload.saved_scenarios.map(&:end_year)).to eq([ 2050, 2030, 2040 ])
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

  describe '#interpolated_scenario_title' do
    let(:limit) { SavedScenario.columns_hash['title'].limit }

    it 'suffixes the collection title with the end year' do
      collection = build(:collection, title: 'Dutch net zero')

      expect(collection.interpolated_scenario_title(2030)).to eq('Dutch net zero (Interpolated 2030)')
    end

    it 'keeps a long title within the SavedScenario title limit' do
      collection = build(:collection, title: 'a' * limit)

      expect(collection.interpolated_scenario_title(2030).length).to eq(limit)
    end

    it 'keeps the end year of a long title' do
      collection = build(:collection, title: 'a' * limit)

      expect(collection.interpolated_scenario_title(2030)).to end_with('(Interpolated 2030)')
    end
  end

  describe 'interpolated collections' do
    let(:user) { create(:user) }
    let(:collection) { create(:collection, interpolation: true, user: user, scenarios_count: 0) }

    def link(end_year, scenario_id, order: 0, area_code: 'nl')
      saved_scenario = create(
        :saved_scenario,
        user: user,
        end_year: end_year,
        area_code: area_code,
        scenario_id: scenario_id
      )

      create(
        :collection_saved_scenario,
        collection: collection,
        saved_scenario: saved_scenario,
        saved_scenario_order: order
      )
    end

    context 'with one saved scenario per end year' do
      before do
        # Linked out of order, but ordered chronologically by saved_scenario_order.
        link(2050, 1, order: 3)
        link(2030, 2, order: 1)
        link(2040, 3, order: 2)

        collection.reload
      end

      it 'is valid' do
        expect(collection).to be_valid
      end

      it 'follows saved_scenario_order' do
        expect(collection.saved_scenarios.map(&:scenario_id)).to eq([ 2, 3, 1 ])
      end

      it 'reports the end years of the saved scenarios' do
        expect(collection.as_json["interpolation_params"]["end_years"])
          .to eq([ 2030, 2040, 2050 ])
      end
    end

    context 'with two saved scenarios sharing an end year' do
      before do
        link(2050, 1)
        link(2050, 2)

        collection.reload
      end

      it 'is not valid' do
        expect(collection).not_to be_valid
      end
    end

    context 'with saved scenarios from different areas' do
      before do
        link(2030, 1, area_code: 'nl')
        link(2050, 2, area_code: 'de')

        collection.reload
      end

      it 'is not valid' do
        expect(collection).not_to be_valid
      end
    end

    context 'with the interpolated scenarios linked as collection scenarios' do
      let(:collection) { create(:collection, interpolation: true, user: user, scenarios_count: 2) }

      before do
        link(2050, 1)
        collection.reload
      end

      it 'is valid' do
        expect(collection).to be_valid
      end

      it 'reports no end year for the scenarios it holds directly' do
        expect(collection.as_json["interpolation_params"]["end_years"]).to eq([ 2050 ])
      end
    end
  end
end
