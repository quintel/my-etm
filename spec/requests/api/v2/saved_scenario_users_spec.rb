# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::SavedScenarioUsers", type: :request, api: true do
  let(:owner)          { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: owner, private: true) }
  let(:path)           { "/api/v2/saved_scenarios/#{saved_scenario.id}/users" }

  describe "PUT /api/v2/saved_scenarios/:saved_scenario_id/users" do
    let!(:collaborator) do
      create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: User::Roles.index_of(:scenario_viewer))
    end

    it "returns 207 with per-item results even when every update succeeds" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:saved_scenario_user_batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(collaborator.reload.role_id).to eq(User::Roles.index_of(:scenario_collaborator))

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok", "id" => collaborator.id, "user_id" => collaborator.user_id,
        "user_email" => collaborator.email, "role" => "scenario_collaborator"
      )
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { id: collaborator.id, role: "scenario_collaborator" },
            { id: -1, role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:saved_scenario_user_batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
      expect(collaborator.reload.role_id).to eq(User::Roles.index_of(:scenario_collaborator))

      failed_item = response.parsed_body["data"].find { |item| item["status"] == "error" }
      expect(failed_item).to eq(
        "status" => "error", "code" => "not_found", "detail" => "Saved scenario user not found",
        "source" => { "pointer" => "/saved_scenario_users/1" }
      )
    end

    it "reports a validation failure per item using the shared error grammar" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id, role: "not_a_real_role" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 1, "total" => 1)

      failed_item = response.parsed_body["data"].first
      expect(failed_item["status"]).to eq("error")
      expect(failed_item["code"]).to eq("validation_failed")
      expect(failed_item["source"]).to eq("pointer" => "/saved_scenario_users/0")
    end

    it "reports one item per submitted item, in order, even when identifiers repeat" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { id: collaborator.id, role: "not_a_real_role" },
            { id: collaborator.id, role: "also_not_real" }
          ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 2, "total" => 2)
      expect(response.parsed_body["data"].map { |item| item.dig("source", "pointer") })
        .to eq([ "/saved_scenario_users/0", "/saved_scenario_users/1" ])
    end

    it "answers 400 param_missing for an empty list rather than a batch of nothing" do
      put(path, headers: v2_bearer(owner, :delete), params: { saved_scenario_users: [] }, as: :json)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("param_missing")
    end

    it "is hidden to a signed-out caller" do
      put(path, params: { saved_scenario_users: [ { id: collaborator.id, role: "scenario_viewer" } ] }, as: :json)

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("not_found")
    end

    it "is hidden to a stranger" do
      put(
        path,
        headers: v2_bearer(create(:user), :delete),
        params: { saved_scenario_users: [ { id: collaborator.id, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:not_found)
    end

    it "does not sync the change to ETEngine - v2 access resolves via a session grant instead" do
      expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id, role: "scenario_collaborator" } ] },
        as: :json
      )
    end

    it "is refused, not hidden, with only the read scope" do
      put(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { id: collaborator.id, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("forbidden")
    end
  end

  describe "POST /api/v2/saved_scenarios/:saved_scenario_id/users" do
    it "returns 207 with per-item results even when every invite succeeds" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { user_email: "new@example.com", role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:saved_scenario_user_batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)

      created = SavedScenarioUser.find_by(saved_scenario: saved_scenario, user_email: "new@example.com")
      expect(created.role_id).to eq(User::Roles.index_of(:scenario_viewer))

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok", "id" => created.id, "user_id" => nil,
        "user_email" => "new@example.com", "role" => "scenario_viewer"
      )
    end

    it "attaches an existing user by id" do
      invitee = create(:user)

      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { user_id: invitee.id, role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(response.parsed_body["data"].first).to include(
        "status" => "ok", "user_id" => invitee.id, "user_email" => invitee.email, "role" => "scenario_viewer"
      )
    end

    it "reports an unknown user id as not_found against the item that named it" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { user_id: -1, role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response.parsed_body).to validate_against_the_v2_envelope(:saved_scenario_user_batch)
      expect(response.parsed_body["data"].first).to eq(
        "status" => "error", "code" => "not_found", "detail" => "User not found",
        "source" => { "pointer" => "/saved_scenario_users/0" }
      )
    end

    it "reports every failing item, even when they share an identifier" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { user_id: -1, role: "scenario_viewer" },
            { user_id: -2, role: "scenario_viewer" },
            { user_id: -3, role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 3, "total" => 3)
      expect(response.parsed_body["data"].map { |item| item.dig("source", "pointer") }).to eq(
        [ "/saved_scenario_users/0", "/saved_scenario_users/1", "/saved_scenario_users/2" ]
      )
    end

    it "reports every validation message for an item in one entry" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 1, "total" => 1)
      expect(response.parsed_body["data"].first["detail"]).to include("Either user_id or user_email")
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { user_email: "valid@example.com", role: "scenario_viewer" },
            { user_email: "invalid@example.com", role: "not_a_real_role" }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
      expect(SavedScenarioUser.exists?(saved_scenario: saved_scenario, user_email: "valid@example.com")).to be(true)

      failed_item = response.parsed_body["data"].find { |item| item["status"] == "error" }
      expect(failed_item["code"]).to eq("validation_failed")
      expect(failed_item["source"]).to eq("pointer" => "/saved_scenario_users/1")
    end

    it "does not sync the change to ETEngine - v2 access resolves via a session grant instead" do
      expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { user_email: "new2@example.com", role: "scenario_viewer" } ] },
        as: :json
      )
    end

    it "is hidden to a signed-out caller" do
      post(path, params: { saved_scenario_users: [ { user_email: "a@example.com", role: "scenario_viewer" } ] }, as: :json)

      expect(response).to have_http_status(:not_found)
    end

    it "is refused, not hidden, with only the read scope" do
      post(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { user_email: "new3@example.com", role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v2/saved_scenarios/:saved_scenario_id/users" do
    let!(:collaborator) do
      create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: User::Roles.index_of(:scenario_viewer))
    end

    it "returns 207 with per-item results even when every removal succeeds" do
      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:saved_scenario_user_batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(SavedScenarioUser.exists?(collaborator.id)).to be(false)

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok", "id" => collaborator.id, "user_id" => collaborator.user_id,
        "user_email" => collaborator.email, "role" => "scenario_viewer"
      )
    end

    it "describes a removed member the same way an updated one is described" do
      member = create(
        :saved_scenario_user,
        saved_scenario: saved_scenario, user: create(:user, email: "coupled@example.com"),
        role_id: User::Roles.index_of(:scenario_viewer)
      )

      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: member.id, role: "scenario_viewer" } ] },
        as: :json
      )
      updated_item = response.parsed_body["data"].first

      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: member.id } ] },
        as: :json
      )

      expect(response.parsed_body["data"].first).to eq(updated_item)
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id }, { id: -1 } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
      expect(SavedScenarioUser.exists?(collaborator.id)).to be(false)

      failed_item = response.parsed_body["data"].find { |item| item["status"] == "error" }
      expect(failed_item).to eq(
        "status" => "error", "code" => "not_found", "detail" => "User not found",
        "source" => { "pointer" => "/saved_scenario_users/1" }
      )
    end

    it "does not remove the last owner" do
      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { user_id: owner.id } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 1, "total" => 1)
      expect(SavedScenarioUser.exists?(saved_scenario: saved_scenario, user_id: owner.id)).to be(true)
    end

    it "does not sync the change to ETEngine - v2 access resolves via a session grant instead" do
      expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { id: collaborator.id } ] },
        as: :json
      )
    end

    it "is hidden to a signed-out caller" do
      delete(path, params: { saved_scenario_users: [ { id: collaborator.id } ] }, as: :json)

      expect(response).to have_http_status(:not_found)
    end

    it "is refused, not hidden, with only the read scope" do
      delete(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { id: collaborator.id } ] },
        as: :json
      )

      expect(response).to have_http_status(:forbidden)
    end
  end
end
