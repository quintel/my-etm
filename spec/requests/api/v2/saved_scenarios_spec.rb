# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::SavedScenarios", type: :request, api: true do
  let(:owner) { create(:user) }

  def count_queries
    count = 0
    callback = ->(*) { count += 1 }

    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { yield }

    count
  end

  describe "GET /api/v2/saved_scenarios" do
    let(:path) { "/api/v2/saved_scenarios" }

    it_behaves_like "a caller-scoped collection endpoint"

    it "lists the caller's own scenarios" do
      own = create(:saved_scenario, user: owner, private: true)

      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:collection)
      expect(response.parsed_body["data"].map { |item| item["id"] }).to eq([ own.id ])
    end

    it "includes scenarios shared with the caller" do
      viewer   = create(:user)
      scenario = create(:saved_scenario, private: true)
      create(
        :saved_scenario_user,
        saved_scenario: scenario, user: viewer, role_id: User::Roles.index_of(:scenario_viewer)
      )

      get(path, headers: v2_bearer(viewer, :read), as: :json)

      expect(response.parsed_body["data"].map { |item| item["id"] }).to include(scenario.id)
    end

    it "does not enumerate public scenarios the caller has no role on" do
      public_scenario = create(:saved_scenario, private: false)

      get(path, headers: v2_bearer(create(:user), :read), as: :json)

      expect(response.parsed_body["data"].map { |item| item["id"] }).not_to include(public_scenario.id)
    end

    it "excludes scenarios the caller cannot access" do
      inaccessible = create(:saved_scenario, private: true)

      get(path, headers: v2_bearer(create(:user), :read), as: :json)

      expect(response.parsed_body["data"].map { |item| item["id"] }).not_to include(inaccessible.id)
    end

    it "excludes discarded scenarios" do
      kept      = create(:saved_scenario, user: owner)
      discarded = create(:saved_scenario, user: owner)
      discarded.discard

      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response.parsed_body["data"].map { |item| item["id"] }).to eq([ kept.id ])
    end

    it "serialises a scenario via the explicit allow-list, without its membership" do
      scenario = create(:saved_scenario, user: owner, private: false)

      get(path, headers: v2_bearer(owner, :read), as: :json)

      entry = response.parsed_body["data"].find { |item| item["id"] == scenario.id }
      expect(entry).to eq(
        "id" => scenario.id,
        "title" => scenario.title,
        "description" => nil,
        "scenario_id" => scenario.scenario_id,
        "area_code" => scenario.area_code,
        "end_year" => scenario.end_year,
        "version" => scenario.version.tag,
        "private" => false,
        "discarded_at" => nil,
        "created_at" => scenario.created_at.as_json,
        "updated_at" => scenario.updated_at.as_json
      )
    end

    it "does not enumerate private scenarios for a token without the read scope" do
      private_own = create(:saved_scenario, user: owner, private: true)
      public_own  = create(:saved_scenario, user: owner, private: false)

      get(path, headers: v2_bearer(owner, :public), as: :json)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body["data"].map { |item| item["id"] }
      expect(ids).to include(public_own.id)
      expect(ids).not_to include(private_own.id)
    end

    it "issues no further query for each additional scenario" do
      create_list(:saved_scenario, 5, user: owner)
      headers = v2_bearer(owner, :read)
      get(path, headers: headers, as: :json)

      few = count_queries { get(path, headers: headers, as: :json) }
      create_list(:saved_scenario, 20, user: owner)
      many = count_queries { get(path, headers: headers, as: :json) }

      expect(many).to eq(few)
    end
  end

  describe "GET /api/v2/saved_scenarios/:id" do
    let(:resource) { create(:saved_scenario, user: owner, private: true) }
    let(:path)     { "/api/v2/saved_scenarios/#{resource.id}" }

    it_behaves_like "a read-protected resource"

    it "renders the single-resource kind for the owner" do
      get(path, headers: v2_bearer(owner, :read), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(response.parsed_body.dig("data", "id")).to eq(resource.id)
    end

    context "when the scenario is public" do
      let(:resource) { create(:saved_scenario, user: owner, private: false) }

      it "is readable by a signed-out caller" do
        get(path, as: :json)

        expect(response).to have_http_status(:ok)
      end
    end

    describe "membership visibility" do
      let(:resource) { create(:saved_scenario, user: owner, private: false) }
      let(:viewer)   { create(:user) }

      before do
        create(
          :saved_scenario_user,
          saved_scenario: resource, user: viewer, role_id: User::Roles.index_of(:scenario_viewer)
        )
      end

      it "is hidden from a signed-out caller, even though the scenario is public" do
        get(path, as: :json)

        expect(response).to have_http_status(:ok)
        expect(response.parsed_body["data"]).not_to have_key("saved_scenario_users")
      end

      it "is hidden from a signed-in caller with no role on the scenario" do
        get(path, headers: v2_bearer(create(:user), :read), as: :json)

        expect(response.parsed_body["data"]).not_to have_key("saved_scenario_users")
      end

      it "is visible to a caller granted the viewer role" do
        get(path, headers: v2_bearer(viewer, :read), as: :json)

        expect(response.parsed_body.dig("data", "saved_scenario_users")).to contain_exactly(
          { "id" => resource.saved_scenario_users.find_by(user: owner).id,
            "user_id" => owner.id, "role" => "scenario_owner" },
          { "id" => resource.saved_scenario_users.find_by(user: viewer).id,
            "user_id" => viewer.id, "role" => "scenario_viewer" }
        )
      end

      it "is visible to the owner" do
        get(path, headers: v2_bearer(owner, :read), as: :json)

        expect(response.parsed_body.dig("data", "saved_scenario_users").length).to eq(2)
      end

      it "is visible to an admin" do
        get(path, headers: v2_bearer(create(:user, admin: true), :read), as: :json)

        expect(response.parsed_body.dig("data", "saved_scenario_users").length).to eq(2)
      end

      describe "email addresses" do
        it "are withheld from a viewer, who may see who has access but not how to contact them" do
          get(path, headers: v2_bearer(viewer, :read), as: :json)

          expect(response.parsed_body.dig("data", "saved_scenario_users").flat_map(&:keys))
            .not_to include("user_email")
        end

        it "are withheld from a caller who can read but not write the scenario" do
          get(path, headers: v2_bearer(owner, :read), as: :json)

          expect(response.parsed_body.dig("data", "saved_scenario_users").flat_map(&:keys))
            .not_to include("user_email")
        end

        it "are shown to a caller who may manage access" do
          get(path, headers: v2_bearer(owner, :write), as: :json)

          expect(response.parsed_body.dig("data", "saved_scenario_users")).to include(
            hash_including("user_id" => viewer.id, "user_email" => viewer.email)
          )
        end

        it "issues no further query for each additional member" do
          headers = v2_bearer(owner, :write)
          get(path, headers: headers, as: :json)

          few = count_queries { get(path, headers: headers, as: :json) }
          create_list(
            :saved_scenario_user, 9,
            saved_scenario: resource, role_id: User::Roles.index_of(:scenario_viewer)
          )
          many = count_queries { get(path, headers: headers, as: :json) }

          expect(many).to eq(few)
        end
      end

      describe "a pending invitee" do
        let!(:invitee) do
          create(
            :saved_scenario_user,
            saved_scenario: resource, user: nil, user_email: "pending@example.com",
            role_id: User::Roles.index_of(:scenario_viewer)
          )
        end

        it "is addressable by id, which the batch endpoints accept" do
          get(path, headers: v2_bearer(owner, :write), as: :json)

          entry = response.parsed_body.dig("data", "saved_scenario_users")
            .find { |member| member["user_email"] == "pending@example.com" }

          expect(entry).to include("id" => invitee.id, "user_id" => nil)
        end

        it "is distinguishable from another pending invitee" do
          other = create(
            :saved_scenario_user,
            saved_scenario: resource, user: nil, user_email: "second@example.com",
            role_id: User::Roles.index_of(:scenario_viewer)
          )

          get(path, headers: v2_bearer(owner, :write), as: :json)

          pending_ids = response.parsed_body.dig("data", "saved_scenario_users")
            .select { |member| member["user_id"].nil? }
            .map { |member| member["id"] }

          expect(pending_ids).to contain_exactly(invitee.id, other.id)
        end
      end
    end
  end

  describe "POST /api/v2/saved_scenarios" do
    let(:path) { "/api/v2/saved_scenarios" }
    let(:attributes) do
      {
        scenario_id: 123_456,
        title: "My scenario",
        area_code: "nl2023",
        end_year: 2050,
        version: Version.default.tag
      }
    end

    it "creates the scenario and renders the single-resource kind" do
      post(path, headers: v2_bearer(owner, :write), params: { saved_scenario: attributes }, as: :json)

      expect(response).to have_http_status(:created)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(response.parsed_body.dig("data", "title")).to eq("My scenario")

      created = SavedScenario.find(response.parsed_body.dig("data", "id"))
      expect(created.users).to eq([ owner ])
    end

    it "renders the caller as owner in the membership list" do
      post(path, headers: v2_bearer(owner, :write), params: { saved_scenario: attributes }, as: :json)

      created = SavedScenario.find(response.parsed_body.dig("data", "id"))

      expect(response.parsed_body.dig("data", "saved_scenario_users")).to eq(
        [ { "id" => created.saved_scenario_users.sole.id, "user_id" => owner.id,
            "role" => "scenario_owner", "user_email" => owner.email } ]
      )
    end

    it "honours a requested version other than the default" do
      other = Version.where.not(id: Version.default.id).first

      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: attributes.merge(version: other.tag) },
        as: :json
      )

      expect(response).to have_http_status(:created)
      expect(response.parsed_body.dig("data", "version")).to eq(other.tag)
      expect(SavedScenario.find(response.parsed_body.dig("data", "id")).version).to eq(other)
    end

    it "reports one error per failing attribute, atomically" do
      post(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: attributes.except(:title, :area_code) },
        as: :json
      )

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:error)
      expect(response.parsed_body["data"]).to be_nil

      pointers = response.parsed_body["errors"].map { |error| error.dig("source", "pointer") }
      expect(pointers).to include("/saved_scenario/title", "/saved_scenario/area_code")
      expect(response.parsed_body["errors"].map { |error| error["code"] }.uniq).to eq([ "validation_failed" ])
      expect(SavedScenario.where(scenario_id: 123_456)).to be_empty
    end

    it "answers 400 param_missing without the saved_scenario key" do
      post(path, headers: v2_bearer(owner, :write), params: {}, as: :json)

      expect(response).to have_http_status(:bad_request)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("param_missing")
    end

    it "is refused, not hidden, with only the read scope" do
      post(path, headers: v2_bearer(owner, :read), params: { saved_scenario: attributes }, as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(response.parsed_body.dig("errors", 0, "code")).to eq("forbidden")
    end

    it "is refused to a signed-out caller" do
      post(path, params: { saved_scenario: attributes }, as: :json)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PUT /api/v2/saved_scenarios/:id" do
    let(:resource) { create(:saved_scenario, user: owner, private: true) }
    let(:path)     { "/api/v2/saved_scenarios/#{resource.id}" }

    it "updates the writable attributes" do
      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: { title: "Renamed", private: false } },
        as: :json
      )

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(resource.reload.title).to eq("Renamed")
      expect(resource.private).to be(false)
    end

    it "does not re-point the engine scenario through the general update action" do
      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: { scenario_id: 999_999 } },
        as: :json
      )

      expect(resource.reload.scenario_id).not_to eq(999_999)
    end

    it "does not change the version through the general update action" do
      other_version = Version.where.not(id: resource.version_id).first

      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: { version: other_version.tag } },
        as: :json
      )

      expect(resource.reload.version_id).not_to eq(other_version.id)
    end

    it "does not discard through the general update action" do
      put(
        path,
        headers: v2_bearer(owner, :write),
        params: { saved_scenario: { discarded: true } },
        as: :json
      )

      expect(resource.reload.discarded_at).to be_nil
    end

    it "reports a validation failure through the error grammar" do
      put(path, headers: v2_bearer(owner, :write), params: { saved_scenario: { title: "" } }, as: :json)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("errors", 0, "source", "pointer")).to eq("/saved_scenario/title")
      expect(resource.reload.title).not_to eq("")
    end

    it "is refused, not hidden, with only the read scope" do
      put(path, headers: v2_bearer(owner, :read), params: { saved_scenario: { title: "x" } }, as: :json)

      expect(response).to have_http_status(:forbidden)
    end

    it "is hidden to a stranger" do
      put(
        path,
        headers: v2_bearer(create(:user), :write),
        params: { saved_scenario: { title: "x" } },
        as: :json
      )

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "DELETE /api/v2/saved_scenarios/:id" do
    let(:resource) { create(:saved_scenario, user: owner, private: true) }
    let(:path)     { "/api/v2/saved_scenarios/#{resource.id}" }

    it "hard-deletes and answers 204" do
      delete(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:no_content)
      expect(response.body).to be_empty
      expect(SavedScenario.exists?(resource.id)).to be(false)
    end

    it "is refused, not hidden, with only the write scope" do
      delete(path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(SavedScenario.exists?(resource.id)).to be(true)
    end

    it "is hidden to a stranger" do
      delete(path, headers: v2_bearer(create(:user), :delete), as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /api/v2/saved_scenarios/:id/discard" do
    let(:resource) { create(:saved_scenario, user: owner, private: true) }
    let(:path)     { "/api/v2/saved_scenarios/#{resource.id}/discard" }

    it "discards for a caller with the delete scope" do
      put(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(resource.reload.discarded_at).not_to be_nil
    end

    it "runs the engine scenario-user cleanup, which v1's own discard skips" do
      expect(CleanupScenarioUsersJob).to receive(:perform_later)

      put(path, headers: v2_bearer(owner, :delete), as: :json)
    end

    it "is refused, not hidden, with only the write scope" do
      put(path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(resource.reload.discarded_at).to be_nil
    end

    it "is hidden to a stranger" do
      put(path, headers: v2_bearer(create(:user), :delete), as: :json)

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PUT /api/v2/saved_scenarios/:id/restore" do
    let(:resource) { create(:saved_scenario, user: owner, private: true) }
    let(:path)     { "/api/v2/saved_scenarios/#{resource.id}/restore" }

    before { resource.discard }

    it "restores for a caller with the delete scope" do
      put(path, headers: v2_bearer(owner, :delete), as: :json)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to validate_against_the_v2_envelope(:resource)
      expect(resource.reload.discarded_at).to be_nil
    end

    it "is refused, not hidden, with only the write scope" do
      put(path, headers: v2_bearer(owner, :write), as: :json)

      expect(response).to have_http_status(:forbidden)
      expect(resource.reload.discarded_at).not_to be_nil
    end
  end
end
