# frozen_string_literal: true

# Opens a scenario: records the caller's current role in their scenario access, then routes
# to the scenario's version of ETModel.
class OpenScenariosController < ApplicationController
  load_resource :saved_scenario, parent: false, only: :show
  before_action :resolve_scenario_access, only: :show, if: :current_user

  # GET /saved_scenarios/:id/open
  def show
    redirect_to(load_url, allow_other_host: true)
  end

  private

  # Records the caller's current role on the scenario. Re-deriving drops the entry of a lost role
  def resolve_scenario_access
    id = @saved_scenario.scenario_id
    level = @saved_scenario.access_level_for(current_user)

    update_scenario_access { |access| level ? access.grant([ [ id, level ] ]) : access }
  end

  def load_url
    url = "#{@saved_scenario.version.model_url}/saved_scenarios/#{@saved_scenario.id}/load"
    request.query_string.present? ? "#{url}?#{request.query_string}" : url
  end
end
