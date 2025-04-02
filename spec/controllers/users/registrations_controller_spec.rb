# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Users::RegistrationsController, type: :request do
  describe "POST /users" do
    let(:valid_params) do
      {
        user: {
          name: "John Doe",
          email: "newuser@quintel.com",
          password: "securepassword"
        }
      }
    end

    context "when recaptcha is not configured" do
      before do
        allow(Settings.recaptcha).to receive(:site_key).and_return(nil)
        allow(Settings.recaptcha).to receive(:secret_key).and_return(nil)
      end

      it "creates a user without recaptcha" do
        expect {
          post user_registration_path, params: valid_params
        }.to change(User, :count).by(1)

        user = User.find_by(email: "newuser@quintel.com")
        expect(user).not_to be_nil
      end
    end

    pending "when recaptcha is configured" do
      before do
        allow(Settings.recaptcha).to receive(:site_key).and_return("dummy-key")
        allow(Settings.recaptcha).to receive(:secret_key).and_return("dummy-secret")
      end

      context "and recaptcha passes" do
        before do
          allow_any_instance_of(Users::RegistrationsController)
            .to receive(:verify_recaptcha)
            .and_return(true)
        end

        it "creates a user successfully" do
          expect {
            post user_registration_path, params: valid_params
          }.to change(User, :count).by(1)
        end
      end

      context "and recaptcha fails" do
        before do
          allow_any_instance_of(Users::RegistrationsController)
            .to receive(:verify_recaptcha)
            .and_return(false)
        end

        it "does not create a user and returns unprocessable entity" do
          expect {
            post user_registration_path, params: valid_params
          }.not_to change(User, :count)

          expect(response).to have_http_status(:unprocessable_entity)
          expect(response.body).to include("reCAPTCHA verification failed")
        end
      end
    end
  end
end
