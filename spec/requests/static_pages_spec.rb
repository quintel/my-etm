require 'rails_helper'

RSpec.describe "StaticPages", type: :request do
  describe "POST /send_message" do
    let(:valid_params) do
      {
        contact_us_message: {
          name: "Jane Person",
          email: "jperson@example.com",
          message: "Hello, I have a question about the model."
        }
      }
    end

    around do |example|
      original_timestamp = InvisibleCaptcha.timestamp_enabled
      original_spinner = InvisibleCaptcha.spinner_enabled
      InvisibleCaptcha.timestamp_enabled = false
      InvisibleCaptcha.spinner_enabled = false
      example.run
      InvisibleCaptcha.timestamp_enabled = original_timestamp
      InvisibleCaptcha.spinner_enabled = original_spinner
    end

    context "when recaptcha is not configured" do
      before do
        allow(Settings.recaptcha).to receive(:site_key).and_return(nil)
        allow(Settings.recaptcha).to receive(:secret_key).and_return(nil)
      end

      it "delivers the message without recaptcha" do
        expect {
          post send_message_path, params: valid_params
        }.to change(ActionMailer::Base.deliveries, :count).by(1)

        expect(response).to redirect_to(contact_path)
      end
    end

    context "when recaptcha is configured" do
      before do
        allow(Settings.recaptcha).to receive(:site_key).and_return("dummy-key")
        allow(Settings.recaptcha).to receive(:secret_key).and_return("dummy-secret")
      end

      context "and recaptcha passes" do
        before do
          allow_any_instance_of(StaticPagesController)
            .to receive(:verify_recaptcha)
            .and_return(true)
        end

        it "delivers the message" do
          expect {
            post send_message_path, params: valid_params
          }.to change(ActionMailer::Base.deliveries, :count).by(1)

          expect(response).to redirect_to(contact_path)
        end
      end

      context "and recaptcha fails" do
        before do
          allow_any_instance_of(StaticPagesController)
            .to receive(:verify_recaptcha)
            .and_return(false)
        end

        it "does not deliver the message and redirects with an alert" do
          expect {
            post send_message_path, params: valid_params
          }.not_to change(ActionMailer::Base.deliveries, :count)

          expect(response).to redirect_to(contact_path)
          expect(flash[:alert]).to include("could not verify")
        end
      end
    end
  end
end
