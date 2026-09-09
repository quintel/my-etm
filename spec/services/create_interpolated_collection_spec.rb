# frozen_string_literal: true

require 'rails_helper'

describe CreateInterpolatedCollection, type: :service do
  let(:scenario) { FactoryBot.create(:saved_scenario, scenario_id: 1, user:) }
  let(:user) { FactoryBot.create(:user) }
  let(:result) { described_class.call(nil, scenario, user, years) }

  # --

  def stub_successful_interpolation(year, id)
    allow(ApiScenario::Interpolate).to receive(:call)
      .with(anything, scenario.scenario_id, year, keep_compatible: true)
      .and_return(ServiceResult.success('id' => id))
  end

  def stub_failed_interpolation(year, errors)
    allow(ApiScenario::Interpolate).to receive(:call)
      .with(anything, scenario.scenario_id, year, keep_compatible: true)
      .and_return(ServiceResult.failure(errors))
  end

  # --

  context 'when the interpolated scenario cannot be given an owner' do
    let(:years) { [2030] }

    before do
      stub_successful_interpolation(2030, 2)
      allow(ApiScenario::SetCompatibility).to receive(:dont_keep_compatible).with(nil, 2)
      allow(SavedScenarioUser).to receive(:create).and_return(SavedScenarioUser.new)
    end

    it 'raises rather than committing a scenario nobody owns' do
      expect { result }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it 'saves no interpolated scenario' do
      expect { result rescue nil }.not_to change(SavedScenario, :count)
    end

    it 'creates no Collection' do
      expect { result rescue nil }.not_to change(Collection, :count)
    end
  end

  context 'when creating scenarios for 2030, 2040' do
    let(:years) { [2030, 2040] }

    context 'when the interpolation is successful' do
      before do
        stub_successful_interpolation(2030, 2)
        stub_successful_interpolation(2040, 3)
      end

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is successful' do
        expect(result).to be_successful
      end

      it 'creates a Collection record' do
        expect(result.value).to be_persisted
      end

      it 'saves the interpolated scenarios as SavedScenarios' do
        expect { result }.to change(SavedScenario, :count).by(2)
      end

      it 'creates no CollectionScenario records' do
        expect { result }.not_to change(CollectionScenario, :count)
      end

      it 'links the interpolated scenarios and the source scenario' do
        expect(result.value.reload.saved_scenarios.map(&:scenario_id)).to eq([2, 3, 1])
      end

      it 'orders the scenarios chronologically' do
        expect(result.value.reload.saved_scenarios.map(&:end_year)).to eq([2030, 2040, 2050])
      end

      it 'names the interpolated scenarios after the collection' do
        titles = result.value.reload.saved_scenarios.map(&:title)

        expect(titles).to eq([
          'Some scenario (Interpolated 2030)',
          'Some scenario (Interpolated 2040)',
          'Some scenario'
        ])
      end

      it 'sets the version on the Collection based on the saved_scenario' do
        expect(result.value.version).to eq(scenario.version)
      end

      it 'takes the area code from the source scenario' do
        areas = result.value.reload.saved_scenarios.map(&:area_code)

        expect(areas).to all(eq(scenario.area_code))
      end

      it 'makes the user the owner of each interpolated scenario' do
        owned = result.value.reload.saved_scenarios.all? { |saved| saved.owner?(user) }

        expect(owned).to be(true)
      end

      it 'asks ETEngine to protect and tag each interpolated scenario' do
        expect { result }
          .to have_enqueued_job(SavedScenarioCallbacksJob).twice
      end

      context 'when the source scenario is private' do
        let(:scenario) { FactoryBot.create(:saved_scenario, scenario_id: 1, private: true, user:) }

        it 'makes the interpolated scenarios private' do
          privacy = result.value.reload.saved_scenarios.map(&:private)

          expect(privacy).to all(be(true))
        end
      end
    end

    context 'when ETEngine returns an error for 2030, but not 2040' do
      before do
        stub_failed_interpolation(2030, ["That didn't work."])
        # The 2040 request is never made.
      end

      it 'returns a ServiceResult' do
        expect(result).to be_a(ServiceResult)
      end

      it 'is not successful' do
        expect(result).not_to be_successful
      end

      it 'does not unprotect any scenarios' do
        # Service should stop immediately after the 2030 scenario, and not
        # attempt to create any more.
        allow(ApiScenario::SetCompatibility).to receive(:dont_keep_compatible)

        result
        expect(ApiScenario::SetCompatibility).not_to have_received(:dont_keep_compatible)
      end

      it 'includes the errors on the Result' do
        expect(result.errors).to eq(["That didn't work."])
      end

      it 'does not create a Collection record' do
        expect { result }.not_to change(Collection, :count)
      end

      it 'does not create any SavedScenario records' do
        expect { result }.not_to change(SavedScenario, :count)
      end
    end

    context 'when ETEngine succeeds for 2030 but not 2040' do
      before do
        stub_successful_interpolation(2030, 2)
        stub_failed_interpolation(2040, ["That didn't work."])

        allow(ApiScenario::SetCompatibility).to receive(:dont_keep_compatible).with(nil, 2)
      end

      it 'is not successful' do
        expect(result).not_to be_successful
      end

      it 'unprotects the successful 2030 scenario' do
        result
        expect(ApiScenario::SetCompatibility).to have_received(:dont_keep_compatible).with(nil, 2)
      end

      it 'does not create any SavedScenario records' do
        expect { result }.not_to change(SavedScenario, :count)
      end

      it 'does not create a Collection record' do
        expect { result }.not_to change(Collection, :count)
      end
    end
  end

  # Sanity check that invalid records raise exceptions.
  context 'when given an invalid user, creating a 2030 scenario' do
    let(:user) { User.new }
    let(:scenario) { FactoryBot.create(:saved_scenario, scenario_id: 1) }
    let(:years) { [2030] }

    before do
      stub_successful_interpolation(2030, 2)
      allow(ApiScenario::SetCompatibility).to receive(:dont_keep_compatible).with(nil, 2)
    end

    it 'raises the error' do
      expect { result }.to raise_error(ActiveRecord::RecordNotSaved)
    end

    it 'unprotects the 2030 scenario' do
      begin
        result
      rescue ActiveRecord::RecordNotSaved
        nil
      end

      expect(ApiScenario::SetCompatibility).to have_received(:dont_keep_compatible).with(nil, 2)
    end
  end
end
