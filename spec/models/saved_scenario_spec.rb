require 'rails_helper'

RSpec.describe SavedScenario, type: :model do
  describe 'publishing to Collections' do
    it 'enqueues an event when the saved scenario is updated' do
      saved_scenario = create(:saved_scenario)

      expect { saved_scenario.update!(scenario_id: 202) }
        .to have_enqueued_job(InvalidateCollectionScenarioJob).with(saved_scenario)
    end
  end

  describe '.destroy_old_discarded!' do
    let(:owner) { create(:user) }
    let!(:old) { create(:saved_scenario, user: owner, discarded_at: 61.days.ago) }

    before do
      create(:saved_scenario, user: owner, discarded_at: 59.days.ago)
      allow(SavedScenario::Purge).to receive(:call)
    end

    it 'purges only scenarios discarded long enough ago, as the robot' do
      described_class.destroy_old_discarded!

      expect(SavedScenario::Purge).to have_received(:call).once.with(old, User.robot)
    end

    context 'when scenario belonged to a collection' do
      let(:collection) { create(:collection, user: owner, scenarios_count: 2) }
      let(:old) { create(:saved_scenario, user: owner) }

      before do
        allow(SavedScenario::Purge).to receive(:call).and_call_original
        allow(ApiScenario::SetBound).to receive(:call).and_return(ServiceResult.success([]))

        create(:collection_saved_scenario, saved_scenario: old, collection: collection)
        old.update(discarded_at: 61.days.ago)
      end

      it 'removes the scenario from the collection' do
        expect { described_class.destroy_old_discarded! }
          .to change { collection.reload.latest_scenario_ids.count }.by(-1)
      end
    end
  end

  describe "#scenario_id_history" do
    subject { SavedScenario.new.scenario_id_history }
    it { is_expected.to be_a(Array) }
  end

  describe 'when the scenario has no FeaturedScenario' do
    it 'is not featured' do
      expect(FactoryBot.create(:saved_scenario)).not_to be_featured
    end
  end

  describe 'when the scenario has a FeaturedScenario' do
    it 'is featured' do
      featured = FactoryBot.create(:featured_scenario)
      expect(featured.saved_scenario).to be_featured
    end
  end

  describe 'add_id_to_history' do
    it "adds the provided id to the end of its history" do
      subject.add_id_to_history("1234")
      expect(subject.scenario_id_history.last).to eq("1234")
    end

    it "increases the amount of items in the history by one" do
      expect { subject.add_id_to_history("1234") }
        .to(change { subject.scenario_id_history.count }.by(1))
    end

    it "won't add more then 100 items" do
      100.times { |n| subject.add_id_to_history(n) }

      expect { subject.add_id_to_history("1234") }
        .not_to change { subject.scenario_id_history.count }
    end
  end

  describe 'restore_historical' do
    before do
      subject.scenario_id_history = [ 123, 1234, 12345 ]
    end

    it 'sets the version as the main scenario id' do
      subject.restore_historical(1234)
      expect(subject.scenario_id).to eq(1234)
    end

    it 'removes old scenarios from history' do
      expect { subject.restore_historical(1234) }
        .to change { subject.scenario_id_history.count }.by(-2)
    end

    it 'keeps correct ids in history' do
      subject.restore_historical(1234)
      expect(subject.scenario_id_history).to eq([ 123 ])
    end

    it 'returns the discarded ids' do
      expect(subject.restore_historical(1234)).to eq([ 123_45 ])
    end

    it 'does nothing when the scenario was not in the history' do
      expect(subject.restore_historical(999_999)).to be_empty
    end
  end

  describe 'version=' do
    let(:version) { create(:version) }
    let(:saved_scenario) { create(:saved_scenario) }

    context 'with a version object' do
      it 'sets the version' do
        expect { saved_scenario.version = version }
          .to change {
            saved_scenario.version.tag
          }.to eq(version.tag)
      end
    end

    context 'with a string tag' do
      it 'sets the version' do
        expect { saved_scenario.version = version.tag }
          .to change {
            saved_scenario.version.tag
          }.to eq(version.tag)
      end
    end
  end

  describe "#access_level_for" do
    let(:saved_scenario) { create(:saved_scenario) }
    let(:user) { create(:user) }

    def give_role(role)
      create(:saved_scenario_user, saved_scenario:, user:, role_id: User::Roles.index_of(role))
    end

    it "gives a collaborator write" do
      give_role(:scenario_collaborator)

      expect(saved_scenario.access_level_for(user)).to eq(ScenarioAccess::WRITE)
    end

    it "gives a viewer read" do
      give_role(:scenario_viewer)

      expect(saved_scenario.access_level_for(user)).to eq(ScenarioAccess::READ)
    end

    it "gives nothing without a role" do
      expect(saved_scenario.access_level_for(user)).to be_nil
    end

    it "gives nothing on a discarded scenario, whatever the role" do
      give_role(:scenario_owner)
      saved_scenario.discard

      expect(saved_scenario.access_level_for(user)).to be_nil
    end
  end
end
