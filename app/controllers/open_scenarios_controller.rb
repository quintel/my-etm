# frozen_string_literal: true

# Opens a scenario: stamps the caller's access grant onto their session cookie, then routes on to
# the scenario's version of ETModel.
#
# Signing in is not required, so a public scenario stays openable while signed out. A caller
# with no role simply gets no grant.
class OpenScenariosController < ApplicationController
  include ScenarioGrants

  # GET /saved_scenarios/:id/open
  def show
    saved_scenario = SavedScenario.find(params[:id])

    stamp_scenario_grant(saved_scenario)
    redirect_to(load_url(saved_scenario), allow_other_host: true)
  end

  private

  def load_url(saved_scenario)
    url = "#{saved_scenario.version.model_url}/saved_scenarios/#{saved_scenario.id}/load"
    request.query_string.present? ? "#{url}?#{request.query_string}" : url
  end
end
