# frozen_string_literal: true

# Opens a scenario: records the caller's current role in their scenario access, then routes
# to the scenario's version of ETModel.
class OpenScenariosController < ApplicationController
  # GET /saved_scenarios/:id/open
  def show
    saved_scenario = SavedScenario.find(params[:id])

    resolve_scenario_access(saved_scenario) if current_user
    redirect_to(load_url(saved_scenario), allow_other_host: true)
  end

  private

  # Records the caller's current role on the scenario, removing any entry a lost role left behind
  def resolve_scenario_access(saved_scenario)
    id = saved_scenario.scenario_id
    level = ScenarioAccess.level_for(saved_scenario, current_user) unless saved_scenario.discarded?

    update_scenario_access { |access| level ? access.grant([ [ id, level ] ]) : access.without(id) }
  end

  def load_url(saved_scenario)
    url = "#{saved_scenario.version.model_url}/saved_scenarios/#{saved_scenario.id}/load"
    request.query_string.present? ? "#{url}?#{request.query_string}" : url
  end
end
