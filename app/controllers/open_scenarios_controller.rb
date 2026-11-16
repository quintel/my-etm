# frozen_string_literal: true

# Opens a scenario: grants its current Session in the caller's scenario access, then routes to the
# scenario's version of ETModel.
class OpenScenariosController < ApplicationController
  load_resource :saved_scenario, parent: false, only: :show
  before_action :grant_current_session, only: :show, if: :current_user

  # GET /saved_scenarios/:id/open
  def show
    redirect_to(load_url, allow_other_host: true)
  end

  private

  def grant_current_session
    grant_sessions([ @saved_scenario.scenario_id ])
  end

  def load_url
    url = "#{@saved_scenario.version.model_url}/saved_scenarios/#{@saved_scenario.id}/load"
    request.query_string.present? ? "#{url}?#{request.query_string}" : url
  end
end
