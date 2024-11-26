require 'rails_helper'

RSpec.describe SavedScenario, type: :model do
  describe "#scenario_id_history" do
    subject { SavedScenario.new.scenario_id_history }
    it { is_expected.to be_a(Array) }
  end

  describe "#scenario" do
    pending "returns nil if scenario is not found in MyEtm" do
      allow(FetchAPIScenario).to receive(:call)
        .with(anything, 0).and_return(ServiceResult.failure('Scenario not found'))

      expect(described_class.new(scenario_id: 0).scenario(Identity.http_client)).to be_nil
    end
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
      expect(subject.restore_historical(999_999)).to be_nil
    end
  end
  describe '#update_with_api_params' do
    let(:ss) { create(:saved_scenario, scenario_id: 1) }

    context 'when discarding a scenario' do
      it 'sets discarded at' do
        expect { ss.update_with_api_params(discarded: true) }
          .to change(ss, :discarded_at)
          .from(nil)
      end
    end

    context 'when discarding an already-discarded scenario' do
      it 'sets discarded at' do
        ss.update!(discarded_at: 1.day.ago)

        expect { ss.update_with_api_params(discarded: true) }
          .not_to change(ss, :discarded_at)
      end
    end

    context 'when undiscarding scenario' do
      it 'unsets discarded at' do
        ss.update!(discarded_at: 1.day.ago)

        expect { ss.update_with_api_params(discarded: false) }
          .to change(ss, :discarded_at)
          .to(nil)
      end
    end

    context 'when given a new scenario_id' do
      it 'returns true' do
        expect(ss.update_with_api_params(scenario_id: 2)).to be(true)
      end

      it 'updates the scenario_id' do
        expect { ss.update_with_api_params(scenario_id: 2) }
          .to change(ss, :scenario_id)
          .from(1).to(2)
      end

      it 'adds the old scenario_id to the history' do
        expect { ss.update_with_api_params(scenario_id: 2) }
          .to change(ss, :scenario_id_history)
          .from([]).to([ 1 ])
      end
    end

    context 'when given no scenario_id' do
      it 'returns true' do
        expect(ss.update_with_api_params(title: 'New title')).to be(true)
      end

      it 'does not update the scenario_id' do
        expect { ss.update_with_api_params(title: 'New title') }
          .not_to change(ss, :scenario_id)
          .from(1)
      end

      it 'does not update the history' do
        expect { ss.update_with_api_params(title: 'New title') }
          .not_to change(ss, :scenario_id_history)
          .from([])
      end
    end

    context 'when given the same scenario_id' do
      it 'returns true' do
        expect(ss.update_with_api_params(scenario_id: 1, title: 'New title')).to be(true)
      end

      it 'does not update the scenario_id' do
        expect { ss.update_with_api_params(scenario_id: 1, title: 'New title') }
          .not_to change(ss, :scenario_id)
          .from(1)
      end

      it 'does not update the history' do
        expect { ss.update_with_api_params(scenario_id: 1, title: 'New title') }
          .not_to change(ss, :scenario_id_history)
          .from([])
      end
    end
  end
end
