# frozen_string_literal: true

require 'rails_helper'

describe CreateSavedScenarioUser, type: :service do
  let(:http_client) { instance_double(Faraday::Connection) }
  let(:user) { FactoryBot.create(:user) }
  let(:saved_scenario) { create(:saved_scenario, id: 123, title: "Test Scenario") }
  let(:settings) { { role_id: 1, user_email: "user@example.com" } }
  let(:service) { described_class.new(http_client, saved_scenario, user.name, settings) }

  describe "#call" do
    context "when the SavedScenarioUser is valid" do
      let!(:initial_user) { create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1) }

      before do
        allow(ScenarioInvitationMailer).to receive(:invite_user).and_call_original
        allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
      end

      it "returns a successful ServiceResult" do
        result = service.call
        expect(result).to be_successful
        expect(result.value).to be_a(SavedScenarioUser)
        expect(result.value).to be_persisted
      end

      it "changes the viewers on the SavedScenario" do
        expect { service.call }.to change(
          saved_scenario.saved_scenario_users, :count
        ).from(1).to(2)
      end

      it "sends an invitation email" do
        service.call
        expect(ScenarioInvitationMailer).to have_received(:invite_user).with(
          "user@example.com",
          "John Doe",
          User::ROLES[1],
          { id: 123, title: "Test Scenario" },
          name: nil
        )
      end


      it "enqueues background jobs for current and historical scenarios" do
        allow(saved_scenario).to receive(:scenario_id_history).and_return([ 101, 102 ])
        allow(SavedScenarioUserCallbacksJob).to receive(:perform_later)

        service.call

        # Expect two calls: one for current scenario (with scenario_id), one for historical scenarios
        expect(SavedScenarioUserCallbacksJob).to have_received(:perform_later).twice
      end
    end

    context "when the SavedScenarioUser is invalid" do
      before do
        allow_any_instance_of(SavedScenarioUser).to receive(:valid?).and_return(false)
        allow_any_instance_of(SavedScenarioUser).to receive_message_chain(:errors,
          :full_messages).and_return([ "Email is invalid" ])
      end

      it "returns a failure ServiceResult" do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to eq([ "Email is invalid" ])
      end
    end

    context 'when the API response is unsuccessful' do
      let(:api_result) { ServiceResult.failure([ 'Nope' ]) }

      it 'returns a ServiceResult' do
        expect(api_result).to be_a(ServiceResult)
      end

      it 'is not successful' do
        expect(api_result).not_to be_successful
      end

      it 'returns the scenario error messages' do
        expect(api_result.errors).to eq([ 'Nope' ])
      end
    end

    context 'when the SavedScenarioUser already exists' do
      before do
        allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
        create(:saved_scenario_user, :with_email, saved_scenario: saved_scenario, role_id: 1)
      end

      it 'returns a failure ServiceResult with "duplicate" error' do
        result = service.call
        expect(result).not_to be_successful
        expect(result.errors).to eq([ "duplicate" ])
      end
    end

    context 'when there is a found linked user' do
      before do
        allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
      end

      let(:existing_user) { create(:user) }
      let(:settings) { { role_id: 1, user_email: existing_user.email } }

      let!(:initial_user) { create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1) }

      it 'is successful' do
        result = service.call
        expect(result).to be_successful
      end

      it 'changes the viewers on the SavedScenario' do
        expect { service.call }.to change(
          saved_scenario.saved_scenario_users, :count
        ).from(1).to(2)
      end

      it 'sets the linked user on the SavedScenarioUser' do
        result = service.call
        expect(result.value.user_id).to eq(existing_user.id)
      end
    end
  end
end
