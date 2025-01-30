require 'rails_helper'

RSpec.describe Identity::AccessTokensController, type: :request do
  let(:user) { create(:user) }
  let(:client) { create(:doorkeeper_application) }
  let(:personal_token) { create(:personal_access_token) }
  let(:expired_PAT) { create(:expired_personal_access_token) }

  describe "POST /identity/access_tokens/exchange" do
    pending "with a valid PAT and client" do
      # TODO match the client in the access token and the params
      it "exchanges a PAT for a new access token" do
        post "/identity/access_tokens/exchange",
          headers: { "Authorization" => "Bearer #{personal_token}" },
          params: { client_id: client.uid }

        expect(response).to have_http_status(:ok)
        json = JSON.parse(response.body)
        expect(json).to include("access_token", "token_type", "expires_in")
      end
    end

    context "with a missing PAT" do
      it "returns an error" do
        post "/identity/access_tokens/exchange",
          params: { client_id: client.uid }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_request")
        expect(json["error_description"]).to eq("Missing PAT")
      end
    end

    context "with an invalid PAT" do
      it "returns an error" do
        post "/identity/access_tokens/exchange",
          headers: { "Authorization" => "Bearer invalid_token" },
          params: { client_id: client.uid }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_request")
        expect(json["error_description"]).to eq("Invalid or expired PAT")
      end
    end

    context "with an expired or revoked PAT" do
      it "returns an error" do
        post "/identity/access_tokens/exchange",
          headers: { "Authorization" => "Bearer #{expired_PAT}" },
          params: { client_id: client.uid }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_request")
        expect(json["error_description"]).to eq("Invalid or expired PAT")
      end
    end

    context "with an invalid client ID" do
      it "returns an error" do
        post "/identity/access_tokens/exchange",
          headers: { "Authorization" => "Bearer #{personal_token}" },
          params: { client_id: "invalid_client" }

        expect(response).to have_http_status(:unauthorized)
        json = JSON.parse(response.body)
        expect(json["error"]).to eq("invalid_request")
        expect(json["error_description"]).to eq("Invalid client")
      end
    end
  end
end
