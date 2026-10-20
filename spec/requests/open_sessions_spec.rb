# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Opening Sessions by ID', type: :request do
  let(:user) { create(:user, :confirmed_at) }
  let(:anchor) do
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
  end
  let(:saved_scenario) { create(:saved_scenario, user: create(:user)) }
  let(:return_to) { "#{Version.default.model_url}/scenarios/#{saved_scenario.scenario_id}/load" }

  before { Version.default }

  def open_sessions(*ids, to: return_to, signed_in: true)
    headers = signed_in ? { 'Cookie' => "etm_session=#{anchor.token}; etm_refresh=#{anchor.refresh_token}" } : {}
    get(open_saved_scenarios_path(session_ids: ids.join(','), return_to: to), headers:)
  end

  def claim
    token = response.cookies[JwtSessionCookies::SESSION_COOKIE]
    token && MyEtm::Auth.verify_jwt(token)&.fetch(ScenarioAccess::CLAIM, nil)
  end

  def give_role(role, scenario = saved_scenario)
    create(:saved_scenario_user, saved_scenario: scenario, user:, role_id: User::Roles.index_of(role))
  end

  it 'returns to the app' do
    open_sessions(saved_scenario.scenario_id)

    expect(response).to redirect_to(return_to)
  end

  it "grants each Session at the caller's role level" do
    viewed = create(:saved_scenario, scenario_id: 700_001)
    give_role(:scenario_collaborator)
    give_role(:scenario_viewer, viewed)
    open_sessions(saved_scenario.scenario_id, viewed.scenario_id)

    expect(claim).to eq('write' => [ saved_scenario.scenario_id ], 'read' => [ viewed.scenario_id ])
  end

  it "adds nothing for a snapshot's Session or a Session without a role" do
    give_role(:scenario_owner)
    saved_scenario.update!(scenario_id_history: [ 700_002 ])
    open_sessions(700_002, create(:saved_scenario, scenario_id: 700_003).scenario_id)

    expect(anchor.reload.scenario_access).to be_nil
  end

  it 'returns a signed-out visitor to the app' do
    open_sessions(saved_scenario.scenario_id, signed_in: false)

    expect(response).to redirect_to(return_to)
  end

  [ nil, 'https://evil.example.com/bad' ].each do |hostile|
    it "refuses return_to #{hostile.inspect}" do
      open_sessions(saved_scenario.scenario_id, to: hostile)

      expect(response).to have_http_status(:bad_request)
    end
  end

  it 'grants nothing when refusing return_to' do
    give_role(:scenario_owner)
    open_sessions(saved_scenario.scenario_id, to: 'https://evil.example.com/bad')

    expect(anchor.reload.scenario_access).to be_nil
  end
end
