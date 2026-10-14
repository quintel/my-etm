# frozen_string_literal: true

require 'rails_helper'

# Opening is where MyETM decides access: it resolves the caller's role and adds it to the scenario
# access on their session cookie. ETEngine authorises from that claim.
RSpec.describe 'Opening a scenario', type: :request do
  let(:user) { create(:user, :confirmed_at) }
  let(:anchor) do
    user.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
  end
  let(:saved_scenario) { create(:saved_scenario, user: create(:user)) }

  before { Version.default }

  def with_session(token)
    { 'Cookie' => "etm_session=#{token.token}; etm_refresh=#{token.refresh_token}" }
  end

  def open_scenario(scenario = saved_scenario, headers: with_session(anchor))
    get(open_saved_scenario_path(scenario), headers:)
  end

  def claim
    token = response.cookies[JwtSessionCookies::SESSION_COOKIE]
    token && MyEtm::Auth.verify_jwt(token)&.fetch(ScenarioAccess::CLAIM, nil)
  end

  def give_role(role, scenario = saved_scenario)
    create(
      :saved_scenario_user,
      saved_scenario: scenario, user:, role_id: User::Roles.index_of(role)
    )
  end

  it 'redirects to the scenario on its own version of ETModel, forwarding the query string' do
    get open_saved_scenario_path(saved_scenario, title: 'Some scenario')

    expect(response).to redirect_to(
      "#{saved_scenario.version.model_url}/saved_scenarios/#{saved_scenario.id}/load?title=Some+scenario"
    )
  end

  it 'adds a write entry for a collaborator' do
    give_role(:scenario_collaborator)
    open_scenario

    expect(claim).to eq('write' => [ saved_scenario.scenario_id ], 'read' => [])
  end

  it 'adds a read entry for a viewer' do
    give_role(:scenario_viewer)
    open_scenario

    expect(claim).to eq('write' => [], 'read' => [ saved_scenario.scenario_id ])
  end

  it 'keeps the first scenario when a second is opened' do
    other = create(:saved_scenario, scenario_id: 700_001)
    give_role(:scenario_owner)
    give_role(:scenario_viewer, other)

    open_scenario
    open_scenario(other)

    expect(claim).to eq('write' => [ saved_scenario.scenario_id ], 'read' => [ other.scenario_id ])
  end

  it 'adds nothing for an admin without a role' do
    user.update!(admin: true)
    open_scenario

    expect(anchor.reload.scenario_access).to be_nil
  end

  it 'adds nothing for a discarded scenario' do
    give_role(:scenario_owner)
    saved_scenario.discard
    open_scenario

    expect(anchor.reload.scenario_access).to be_nil
  end

  it 'downgrades a held write when the role is now viewer' do
    role = give_role(:scenario_collaborator)
    open_scenario
    role.update!(role_id: User::Roles.index_of(:scenario_viewer))
    open_scenario

    expect(claim).to eq('write' => [], 'read' => [ saved_scenario.scenario_id ])
  end

  it 'removes a held entry when the role is gone' do
    role = give_role(:scenario_owner)
    open_scenario
    role.destroy!
    open_scenario

    expect(anchor.reload.scenario_access).to be_nil
  end

  it 'redirects a signed-out visitor without a session cookie' do
    open_scenario(headers: {})

    expect(response).to have_http_status(:redirect)
    expect(response.cookies[JwtSessionCookies::SESSION_COOKIE]).to be_blank
  end
end
