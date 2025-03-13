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

      it "returns a successful ServiceResult with a persisted SavedScenarioUser" do
        result = service.call

        aggregate_failures do
          expect(result).to be_successful
          expect(result.value).to be_a(SavedScenarioUser)
          expect(result.value).to be_persisted
        end
      end

      it "increments the count of viewers on the SavedScenario" do
        expect { service.call }.to change(saved_scenario.saved_scenario_users, :count).from(1).to(2)
      end

      it "sends an invitation email with correct parameters" do
        service.call
        expect(ScenarioInvitationMailer).to have_received(:invite_user).with(
          "user@example.com",
          "John Doe",
          User::ROLES[1],
          { id: 123, title: "Test Scenario" },
          name: nil
        )
      end

      context "when updating historical scenarios" do
        before do
          allow(saved_scenario).to receive(:scenario_id_history).and_return([ 101, 102 ])
          allow(ApiScenario::Users::Create).to receive(:call).and_return(ServiceResult.success)
        end

        it "calls the API for each historical scenario" do
          service.call

          aggregate_failures do
            expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 101, instance_of(Hash))
            expect(ApiScenario::Users::Create).to have_received(:call).with(http_client, 102, instance_of(Hash))
          end
        end
      end
    end

    context "when the SavedScenarioUser is invalid" do
      before do
        allow_any_instance_of(SavedScenarioUser).to receive(:valid?).and_return(false)
        allow_any_instance_of(SavedScenarioUser).to receive_message_chain(:errors, :messages,
          :keys).and_return([ :email ])
      end

      it "returns a failure ServiceResult with errors" do
        result = service.call

        aggregate_failures do
          expect(result).not_to be_successful
          expect(result.errors).to eq([ :email ])
        end
      end
    end

    context "when the API response is unsuccessful" do
      let(:api_result) { ServiceResult.failure([ "Nope" ]) }

      it "returns an unsuccessful ServiceResult with errors" do
        aggregate_failures do
          expect(api_result).to be_a(ServiceResult)
          expect(api_result).not_to be_successful
          expect(api_result.errors).to eq([ "Nope" ])
        end
      end
    end

    context "when the SavedScenarioUser already exists" do
      before { create(:saved_scenario_user, :with_email, saved_scenario: saved_scenario, role_id: 1) }

      it "returns a failure ServiceResult with 'duplicate' error" do
        result = service.call

        aggregate_failures do
          expect(result).not_to be_successful
          expect(result.errors).to eq([ "duplicate" ])
        end
      end
    end

    context "when there is a found linked user" do
      let(:existing_user) { create(:user) }
      let(:settings) { { role_id: 1, user_email: existing_user.email } }
      let!(:initial_user) { create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1) }

      it "is successful" do
        result = service.call
        expect(result).to be_successful
      end

      it "increments the count of viewers on the SavedScenario" do
        expect { service.call }.to change(saved_scenario.saved_scenario_users, :count).from(1).to(2)
      end

      it "sets the linked user on the SavedScenarioUser" do
        result = service.call
        expect(result.value.user_id).to eq(existing_user.id)
      end
    end
  end
end
