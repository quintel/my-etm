# frozen_string_literal: true

require 'rails_helper'

# Opening is where MyETM decides access: it resolves the caller's role and re-issues the session
# cookie carrying a grant for the scenario the browser is about to edit. ETEngine authorises from
# that claim.
RSpec.describe 'Opening a scenario', type: :request do
  let(:owner) { create(:user, :confirmed_at) }
  let(:saved_scenario) { create(:saved_scenario, user: owner) }

  before { Version.default }

  def open_scenario(as: nil)
    sign_in(as) if as
    get open_saved_scenario_path(saved_scenario)
  end

  def grant_claim
    token = response.cookies[JwtSessionCookies::SESSION_COOKIE]
    token && MyEtm::Auth.verify_jwt(token)&.fetch(ScenarioGrant::CLAIM, nil)
  end

  def add_user(user, role)
    create(
      :saved_scenario_user,
      saved_scenario: saved_scenario, user: user, role_id: User::Roles.index_of(role)
    )
  end

  it 'redirects to the scenario on its own version of ETModel' do
    open_scenario(as: owner)

    expect(response).to redirect_to(
      "#{saved_scenario.version.model_url}/saved_scenarios/#{saved_scenario.id}/load"
    )
  end

  it 'forwards the query string ETModel expects' do
    sign_in(owner)
    get open_saved_scenario_path(saved_scenario, title: 'Some scenario')

    expect(response.location).to end_with('/load?title=Some+scenario')
  end

  it 'mints a write grant for the owner, keyed on the current scenario id' do
    open_scenario(as: owner)

    expect(grant_claim).to eq('scenario_id' => saved_scenario.scenario_id, 'level' => 'write')
  end

  it 'mints a write grant for a collaborator' do
    collaborator = create(:user, :confirmed_at)
    add_user(collaborator, :scenario_collaborator)

    open_scenario(as: collaborator)

    expect(grant_claim).to eq('scenario_id' => saved_scenario.scenario_id, 'level' => 'write')
  end

  it 'mints a read grant for a viewer' do
    viewer = create(:user, :confirmed_at)
    add_user(viewer, :scenario_viewer)

    open_scenario(as: viewer)

    expect(grant_claim).to eq('scenario_id' => saved_scenario.scenario_id, 'level' => 'read')
  end

  it 'mints no grant for a caller with no role, and leaves the session alone' do
    open_scenario(as: create(:user, :confirmed_at))

    expect(response.cookies[JwtSessionCookies::SESSION_COOKIE]).to be_blank
  end

  it 'mints no grant for a signed-out visitor' do
    open_scenario

    expect(response.cookies[JwtSessionCookies::SESSION_COOKIE]).to be_blank
  end

  it 'leaves the browser one live session token' do
    expect { open_scenario(as: owner) }.to change { owner.access_tokens.count }.by(1)
  end

  it 'keeps the grant when the session slides mid-edit' do
    open_scenario(as: owner)
    refresh_cookie = response.cookies[JwtSessionCookies::REFRESH_COOKIE]

    post '/session/refresh',
      headers: { 'Cookie' => "#{JwtSessionCookies::REFRESH_COOKIE}=#{refresh_cookie}" }

    expect(grant_claim).to eq('scenario_id' => saved_scenario.scenario_id, 'level' => 'write')
  end
end
