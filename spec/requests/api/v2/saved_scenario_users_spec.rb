# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::SavedScenarioUsers", type: :request, api: true do
  let(:owner)          { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, user: owner, private: true) }
  let(:path)           { "/api/v2/saved_scenarios/#{saved_scenario.id}/users" }

  describe "GET /api/v2/saved_scenarios/:saved_scenario_id/users" do
    let!(:viewer_membership) do
      create(
        :saved_scenario_user,
        saved_scenario: saved_scenario, role_id: User::Roles.index_of(:scenario_viewer)
      )
    end

    # Counts the SQL queries a block issues: an N+1 shows up as a count that grows with the data.
    def count_queries
      count = 0
      callback = ->(*) { count += 1 }

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }

      count
    end

    it "lists every membership, with the email of each" do
      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
      expect(response.parsed_body["data"]).to contain_exactly(
        { "email" => owner.email, "role" => "scenario_owner", "pending" => false },
        { "email" => viewer_membership.email, "role" => "scenario_viewer", "pending" => false }
      )
    end

    # Someone invited at an address they have no account for is addressed by that same address,
    # and the roster says they have not signed up rather than leaving it to be inferred.
    it "reports an invitee with no account as pending" do
      create(
        :saved_scenario_user,
        saved_scenario: saved_scenario, user: nil, user_email: "pending@example.com",
        role_id: User::Roles.index_of(:scenario_viewer)
      )

      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response.parsed_body["data"]).to include(
        { "email" => "pending@example.com", "role" => "scenario_viewer", "pending" => true }
      )
    end

    it "distinguishes one pending invitee from another" do
      create(
        :saved_scenario_user, saved_scenario: saved_scenario, user: nil,
        user_email: "first@example.com", role_id: User::Roles.index_of(:scenario_viewer)
      )
      create(
        :saved_scenario_user, saved_scenario: saved_scenario, user: nil,
        user_email: "second@example.com", role_id: User::Roles.index_of(:scenario_viewer)
      )

      get(path, headers: v2_bearer(owner, :read), as: :json)

      pending = response.parsed_body["data"].select { |member| member["pending"] }
      expect(pending.map { |member| member["email"] })
        .to contain_exactly("first@example.com", "second@example.com")
    end

    it "is readable by an admin" do
      get(path, headers: v2_bearer(create(:user, admin: true), :read), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["data"].length).to eq(2)
    end

    it "is hidden to a stranger" do
      get(path, headers: v2_bearer(create(:user), :read), as: :json)

      expect(response).to have_http_status(:not_found)
    end

    # Who holds a role is the owner's business: a member may use the scenario without learning who
    # else reaches it. The scenario is not hidden from them, since they may read it, so this is a
    # refusal rather than a 404.
    it "is refused to a viewer" do
      get(path, headers: v2_bearer(viewer_membership.user, :read), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("forbidden")
    end

    it "is refused to a collaborator, who may edit the scenario but not see who reaches it" do
      collaborator = create(:user)
      create(
        :saved_scenario_user, saved_scenario: saved_scenario, user: collaborator,
        role_id: User::Roles.index_of(:scenario_collaborator)
      )

      get(path, headers: v2_bearer(collaborator, :delete), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("forbidden")
    end

    it "is told to authenticate when signed out" do
      get(path, as: :json)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("unauthenticated")
    end

    it "issues no further query for each additional member" do
      headers = v2_bearer(owner, :read)
      get(path, headers: headers, as: :json)

      few = count_queries { get(path, headers: headers, as: :json) }
      create_list(
        :saved_scenario_user, 9,
        saved_scenario: saved_scenario, role_id: User::Roles.index_of(:scenario_viewer)
      )
      many = count_queries { get(path, headers: headers, as: :json) }

      expect(many).to eq(few)
    end
  end

  describe "PUT /api/v2/saved_scenarios/:saved_scenario_id/users" do
    let!(:collaborator) do
      create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: User::Roles.index_of(:scenario_viewer))
    end

    it "returns 207 with per-item results even when every update succeeds" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: collaborator.email, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(collaborator.reload.role_id).to eq(User::Roles.index_of(:scenario_collaborator))

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok",
        "data" => {
          "email" => collaborator.email, "role" => "scenario_collaborator", "pending" => false
        }
      )
    end

    # Read-only members are ignored rather than refused, so a caller can send an item back as the
    # index gave it to them.
    it "ignores pending, which a caller can only have fetched" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: collaborator.email, role: "scenario_collaborator", pending: false }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(collaborator.reload.role).to eq(:scenario_collaborator)
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: collaborator.email, role: "scenario_collaborator" },
            { email: "missing1@example.com", role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
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
        params: { saved_scenario_users: [ { email: collaborator.email, role: "not_a_real_role" } ] },
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
            { email: collaborator.email, role: "not_a_real_role" },
            { email: collaborator.email, role: "also_not_real" }
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

    it "answers 400 param_invalid for an object where a list belongs" do
      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: { email: collaborator.email, role: "scenario_viewer" } },
        as: :json
      )

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["errors"].first).to include(
        "code" => "param_invalid",
        "source" => { "pointer" => "/saved_scenario_users" }
      )
    end

    it "still accepts an id, which is how an existing membership is addressed" do
      member = create(:saved_scenario_user, saved_scenario: saved_scenario, role_id: 1)

      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: member.email, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(member.reload.role).to eq(:scenario_collaborator)
    end

    it "refuses a batch over the limit" do
      over = Api::V2::BaseController::BATCH_LIMIT + 1
      items = Array.new(over) { { email: collaborator.email, role: "scenario_viewer" } }

      put(path, headers: v2_bearer(owner, :delete), params: { saved_scenario_users: items }, as: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("validation_failed")
    end

    it "addresses a coupled member by the email the API reports for them" do
      member = create(
        :saved_scenario_user,
        saved_scenario: saved_scenario, user: create(:user, email: "coupled@example.com"),
        role_id: User::Roles.index_of(:scenario_viewer)
      )

      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [ { email: "coupled@example.com", role: "scenario_collaborator" } ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(member.reload.role_id).to eq(User::Roles.index_of(:scenario_collaborator))
    end

    it "is told to authenticate when signed out" do
      put(path, params: { saved_scenario_users: [ { email: collaborator.email, role: "scenario_viewer" } ] }, as: :json)

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("unauthenticated")
    end

    it "is hidden to a stranger" do
      put(
        path,
        headers: v2_bearer(create(:user), :delete),
        params: { saved_scenario_users: [ { email: collaborator.email, role: "scenario_collaborator" } ] },
        as: :json
      )

      expect(response).to have_http_status(:not_found)
    end

    it "does not sync the change to ETEngine - v2 access resolves via a session grant instead" do
      expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

      put(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: collaborator.email, role: "scenario_collaborator" } ] },
        as: :json
      )
    end

    it "is refused, not hidden, with only the read scope" do
      put(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { email: collaborator.email, role: "scenario_collaborator" } ] },
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
        params: { saved_scenario_users: [ { email: "new@example.com", role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)

      created = SavedScenarioUser.find_by(saved_scenario: saved_scenario, user_email: "new@example.com")
      expect(created.role_id).to eq(User::Roles.index_of(:scenario_viewer))

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok",
        "data" => {
          "email" => "new@example.com", "role" => "scenario_viewer", "pending" => true
        }
      )
    end

    it "attaches an existing user by their address" do
      invitee = create(:user)

      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: invitee.email, role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(response.parsed_body["data"].first).to include(
        "status" => "ok",
        "data" => hash_including(
          "email" => invitee.email, "role" => "scenario_viewer", "pending" => false
        )
      )
    end

    # There is no account to fail to find: an address nobody has registered is an invitation.
    it "invites an address that has no account yet" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [ { email: "nobody@example.com", role: "scenario_viewer" } ]
        },
        as: :json
      )

      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
      expect(response.parsed_body["data"].first).to eq(
        "status" => "ok",
        "data" => {
          "email" => "nobody@example.com", "role" => "scenario_viewer", "pending" => true
        }
      )
    end

    it "reports every failing item at its own position" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "a@example.com", role: "not_a_real_role" },
            { email: "b@example.com", role: "not_a_real_role" },
            { email: "c@example.com", role: "not_a_real_role" }
          ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 0, "failed" => 3, "total" => 3)
      expect(response.parsed_body["data"].map { |item| item.dig("source", "pointer") }).to eq(
        [ "/saved_scenario_users/0", "/saved_scenario_users/1", "/saved_scenario_users/2" ]
      )
    end

    # Left to the model this answers "Either user_id or user_email should be present", naming two
    # members V2 does not have, so the controller refuses it first - and refuses the whole batch,
    # as it does for an item naming an id.
    it "refuses an item that addresses nobody" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { role: "scenario_viewer" } ] },
        as: :json
      )

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "param_invalid",
        "detail" => "is required to address a member",
        "source" => { "pointer" => "/saved_scenario_users/0/email" }
      )
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "valid@example.com", role: "scenario_viewer" },
            { email: "invalid@example.com", role: "not_a_real_role" }
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

    it "says what already exists when the same invitee appears twice in one batch" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "dup@example.com", role: "scenario_viewer" },
            { email: "dup@example.com", role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
      expect(response.parsed_body["data"].last).to include(
        "status" => "error",
        "code" => "validation_failed",
        "detail" => "This user already has access to this scenario",
        "source" => { "pointer" => "/saved_scenario_users/1" }
      )
    end

    it "keeps the members it created when a later item fails" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "kept@example.com", role: "scenario_viewer" },
            { email: "bad@example.com", role: "not_a_real_role" }
          ]
        },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 1, "total" => 2)
      expect(
        SavedScenarioUser.exists?(saved_scenario: saved_scenario, user_email: "kept@example.com")
      ).to be(true)
    end

    it "does not sync the change to ETEngine - v2 access resolves via a session grant instead" do
      expect(SavedScenarioUserCallbacksJob).not_to receive(:perform_later)

      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: "new2@example.com", role: "scenario_viewer" } ] },
        as: :json
      )
    end

    it "is told to authenticate when signed out" do
      post(path, params: { saved_scenario_users: [ { email: "a@example.com", role: "scenario_viewer" } ] }, as: :json)

      expect(response).to have_http_status(:unauthorized)
    end

    it "refuses an item naming an internal id, rather than dropping it without a word" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "first@example.com", role: "scenario_viewer" },
            { id: 4242, role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "param_invalid",
        "detail" => "is not a member of this resource",
        "source" => { "pointer" => "/saved_scenario_users/1/id" }
      )
      expect(SavedScenarioUser.exists?(4242)).to be(false)
    end

    it "applies nothing when one item names an id, so the batch is not half done" do
      post(
        path,
        headers: v2_bearer(owner, :delete),
        params: {
          saved_scenario_users: [
            { email: "kept@example.com", role: "scenario_viewer" },
            { id: 4243, email: "other@example.com", role: "scenario_viewer" }
          ]
        },
        as: :json
      )

      expect(response).to have_http_status(:bad_request)
      expect(SavedScenarioUser.exists?(user_email: "kept@example.com")).to be(false)
    end

    it "refuses a batch over the limit, as one error rather than one per item" do
      over = Api::V2::BaseController::BATCH_LIMIT + 1
      items = Array.new(over) { |i| { email: "bulk#{i}@example.com", role: "scenario_viewer" } }

      post(path, headers: v2_bearer(owner, :delete), params: { saved_scenario_users: items }, as: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["errors"].sole).to include(
        "code" => "validation_failed",
        "detail" => "size cannot be greater than 100",
        "source" => { "pointer" => "/saved_scenario_users" }
      )
      expect(SavedScenarioUser.where(saved_scenario: saved_scenario).count).to eq(1)
    end

    it "accepts a batch at the limit" do
      items = Array.new(Api::V2::BaseController::BATCH_LIMIT) do |i|
        { email: "atlimit#{i}@example.com", role: "scenario_viewer" }
      end

      post(path, headers: v2_bearer(owner, :delete), params: { saved_scenario_users: items }, as: :json)

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body.dig("meta", "batch", "succeeded"))
        .to eq(Api::V2::BaseController::BATCH_LIMIT)
    end

    context "when the scenario has been discarded" do
      before { saved_scenario.discard }

      it "refuses to grant access to a scenario in the bin" do
        post(
          path,
          headers: v2_bearer(owner, :delete),
          params: { saved_scenario_users: [ { email: "binned@example.com", role: "scenario_viewer" } ] },
          as: :json
        )

        expect(response).to have_http_status(:conflict)
        expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
        expect(response.parsed_body["errors"].sole).to include(
          "code" => "scenario_discarded", "detail" => "Saved scenario is discarded"
        )
        expect(SavedScenarioUser.exists?(user_email: "binned@example.com")).to be(false)
      end

      it "tells a stranger nothing about the scenario's state" do
        post(
          path,
          headers: v2_bearer(create(:user), :delete),
          params: { saved_scenario_users: [ { email: "binned@example.com", role: "scenario_viewer" } ] },
          as: :json
        )

        expect(response).to have_http_status(:not_found)
      end

      it "still allows revoking access, which stays useful until the auto-delete" do
        member = create(
          :saved_scenario_user, saved_scenario: saved_scenario,
          role_id: User::Roles.index_of(:scenario_viewer)
        )

        delete(
          path, headers: v2_bearer(owner, :delete),
          params: { saved_scenario_users: [ { email: member.email } ] }, as: :json
        )

        expect(response).to have_http_status(:multi_status)
        expect(SavedScenarioUser.exists?(member.id)).to be(false)
      end

      it "still allows changing a role" do
        member = create(
          :saved_scenario_user, saved_scenario: saved_scenario,
          role_id: User::Roles.index_of(:scenario_viewer)
        )

        put(
          path, headers: v2_bearer(owner, :delete),
          params: { saved_scenario_users: [ { email: member.email, role: "scenario_collaborator" } ] },
          as: :json
        )

        expect(response).to have_http_status(:multi_status)
        expect(member.reload.role).to eq(:scenario_collaborator)
      end
    end

    it "is refused, not hidden, with only the read scope" do
      post(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { email: "new3@example.com", role: "scenario_viewer" } ] },
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
        params: { saved_scenario_users: [ { email: collaborator.email } ] },
        as: :json
      )

      expect(response).to have_http_status(:multi_status)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(SavedScenarioUser.exists?(collaborator.id)).to be(false)

      item = response.parsed_body["data"].first
      expect(item).to eq(
        "status" => "ok",
        "data" => {
          "email" => collaborator.email, "role" => "scenario_viewer", "pending" => false
        }
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
        params: { saved_scenario_users: [ { email: member.email, role: "scenario_viewer" } ] },
        as: :json
      )
      updated_item = response.parsed_body["data"].first

      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: member.email } ] },
        as: :json
      )

      expect(response.parsed_body["data"].first).to eq(updated_item)
    end

    it "persists the valid items and reports the invalid ones per item, still as 207" do
      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: collaborator.email }, { email: "missing1@example.com" } ] },
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

    it "removes a coupled member addressed by the email the API reports for them" do
      member = create(
        :saved_scenario_user,
        saved_scenario: saved_scenario, user: create(:user, email: "coupled@example.com"),
        role_id: User::Roles.index_of(:scenario_viewer)
      )

      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: "coupled@example.com" } ] },
        as: :json
      )

      expect(response.parsed_body.dig("meta", "batch")).to eq("succeeded" => 1, "failed" => 0, "total" => 1)
      expect(SavedScenarioUser.exists?(member.id)).to be(false)
    end

    it "does not remove the last owner" do
      delete(
        path,
        headers: v2_bearer(owner, :delete),
        params: { saved_scenario_users: [ { email: owner.email } ] },
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
        params: { saved_scenario_users: [ { email: collaborator.email } ] },
        as: :json
      )
    end

    it "is told to authenticate when signed out" do
      delete(path, params: { saved_scenario_users: [ { email: collaborator.email } ] }, as: :json)

      expect(response).to have_http_status(:unauthorized)
    end

    it "is refused, not hidden, with only the read scope" do
      delete(
        path,
        headers: v2_bearer(owner, :read),
        params: { saved_scenario_users: [ { email: collaborator.email } ] },
        as: :json
      )

      expect(response).to have_http_status(:forbidden)
    end
  end

  # Managing access answers to :destroy, so it is owners and admins only. A caller without that
  # right is refused outright, which is why nothing here refuses per item.
  describe "who may manage members" do
    let(:collaborator) { create(:user) }
    let(:viewer)       { create(:user) }

    let!(:viewer_membership) do
      create(
        :saved_scenario_user, saved_scenario: saved_scenario, user: viewer,
        role_id: User::Roles.index_of(:scenario_viewer)
      )
    end

    before do
      create(
        :saved_scenario_user, saved_scenario: saved_scenario, user: collaborator,
        role_id: User::Roles.index_of(:scenario_collaborator)
      )
    end

    def set_role(actor, membership, role)
      put(
        path,
        headers: v2_bearer(actor, :delete),
        params: { saved_scenario_users: [ { email: membership.email, role: role } ] },
        as: :json
      )
    end

    def remove(actor, membership)
      delete(
        path,
        headers: v2_bearer(actor, :delete),
        params: { saved_scenario_users: [ { email: membership.email } ] },
        as: :json
      )
    end

    context "as an owner" do
      it "may grant a collaborator role" do
        set_role(owner, viewer_membership, "scenario_collaborator")

        expect(viewer_membership.reload.role).to eq(:scenario_collaborator)
      end

      it "may grant ownership" do
        set_role(owner, viewer_membership, "scenario_owner")

        expect(viewer_membership.reload.role).to eq(:scenario_owner)
      end

      it "may remove a member" do
        remove(owner, viewer_membership)

        expect(SavedScenarioUser.exists?(viewer_membership.id)).to be(false)
      end
    end

    # A collaborator may edit the scenario but not who reaches it, as in the UI.
    context "as a collaborator" do
      it "may not change a role" do
        set_role(collaborator, viewer_membership, "scenario_collaborator")

        expect(response).to have_http_status(:forbidden)
        expect(viewer_membership.reload.role).to eq(:scenario_viewer)
      end

      it "may not remove a member" do
        remove(collaborator, viewer_membership)

        expect(response).to have_http_status(:forbidden)
        expect(SavedScenarioUser.exists?(viewer_membership.id)).to be(true)
      end

      it "may not invite anyone" do
        post(
          path,
          headers: v2_bearer(collaborator, :delete),
          params: {
            saved_scenario_users: [ { email: "new@example.com", role: "scenario_viewer" } ]
          },
          as: :json
        )

        expect(response).to have_http_status(:forbidden)
        expect(SavedScenarioUser.exists?(user_email: "new@example.com")).to be(false)
      end
    end

    context "as a viewer" do
      it "may not manage members at all" do
        set_role(viewer, viewer_membership, "scenario_collaborator")

        expect(response).to have_http_status(:forbidden)
        expect(viewer_membership.reload.role).to eq(:scenario_viewer)
      end
    end

    context "as an admin" do
      let(:admin) { create(:user, admin: true) }

      it "may grant ownership, as an owner may" do
        set_role(admin, viewer_membership, "scenario_owner")

        expect(viewer_membership.reload.role).to eq(:scenario_owner)
      end
    end

    it "refuses an owner holding only the write scope" do
      put(
        path,
        headers: v2_bearer(owner, :write),
        params: {
          saved_scenario_users: [ { email: viewer_membership.email, role: "scenario_collaborator" } ]
        },
        as: :json
      )

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "a role that is not a role name" do
    let!(:member) do
      create(
        :saved_scenario_user, saved_scenario: saved_scenario,
        role_id: User::Roles.index_of(:scenario_viewer)
      )
    end

    [ 1, 3.5, true, "not_a_real_role", "" ].each do |role|
      it "answers #{role.inspect} as a per-item validation failure rather than raising" do
        put(
          path,
          headers: v2_bearer(owner, :delete),
          params: { saved_scenario_users: [ { email: member.email, role: role } ] },
          as: :json
        )

        expect(response).to have_http_status(:multi_status)
        expect(response.parsed_body).to validate_against_the_v2_envelope(:batch)
        expect(response.parsed_body.dig("data", 0, "code")).to eq("validation_failed")
        expect(member.reload.role).to eq(:scenario_viewer)
      end
    end
  end
end
