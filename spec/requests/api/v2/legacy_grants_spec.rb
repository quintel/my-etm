# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Api::V2::LegacyGrants", type: :request, api: true do
  let(:user) { create(:user) }
  let(:saved_scenario) { create(:saved_scenario, scenario_id: 10) }

  let(:pat) do
    CreatePersonalAccessToken.call(user:, params: { name: "pyetm", permissions: :read })
      .value!.oauth_access_token
  end

  let(:pat_header) { { "Authorization" => "Bearer #{pat.token}" } }

  def give_role(role)
    create(:saved_scenario_user, saved_scenario:, user:, role_id: User::Roles.index_of(role))
  end

  def lookup(headers, session_id = 10)
    get("/api/v2/legacy_grants/#{session_id}", headers:, as: :json)
    response.parsed_body["data"]
  end

  it "gives an owner's PAT write" do
    give_role(:scenario_owner)

    expect(lookup(pat_header)).to eq("write" => [ 10 ], "read" => [])
  end

  it "gives a collaborator's PAT write" do
    give_role(:scenario_collaborator)

    expect(lookup(pat_header)).to eq("write" => [ 10 ], "read" => [])
  end

  it "gives a viewer's PAT read" do
    give_role(:scenario_viewer)

    expect(lookup(pat_header)).to eq("write" => [], "read" => [ 10 ])
  end

  it "gives read on a snapshot, even to an owner" do
    saved_scenario.update!(scenario_id: 11, scenario_id_history: [ 10 ])
    give_role(:scenario_owner)

    expect(lookup(pat_header)).to eq("write" => [], "read" => [ 10 ])
  end

  it "keeps the stronger level when two scenarios hold the Session" do
    give_role(:scenario_viewer)
    create(:saved_scenario, scenario_id: 10, user:)

    expect(lookup(pat_header)).to eq("write" => [ 10 ], "read" => [])
  end

  it "gives nothing on a discarded scenario" do
    give_role(:scenario_owner)
    saved_scenario.discard

    expect(lookup(pat_header)).to eq("write" => [], "read" => [])
  end

  it "gives a PAT with no role nothing" do
    saved_scenario

    expect(lookup(pat_header)).to eq("write" => [], "read" => [])
  end

  it "gives nothing on a Session no scenario is bound to" do
    give_role(:scenario_owner)

    expect(lookup(pat_header, 99)).to eq("write" => [], "read" => [])
  end

  it "refuses a revoked PAT" do
    give_role(:scenario_owner)
    pat.revoke

    lookup(pat_header)
    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses an expired PAT" do
    give_role(:scenario_owner)
    pat.update!(created_at: 31.days.ago)

    lookup(pat_header)
    expect(response).to have_http_status(:unauthorized)
  end

  it "refuses a token that is not a PAT" do
    give_role(:scenario_owner)

    lookup(v2_bearer(user, :read))
    expect(response).to have_http_status(:unauthorized)
  end
end
