# frozen_string_literal: true

# Turns a caller's role on a scenario into a ScenarioGrant on their session cookie.
module ScenarioGrants
  extend ActiveSupport::Concern

  private

  # Nil when the caller has no role: nothing to grant. `collaborator?` is true for owners too, so
  # both are named to keep the write case readable.
  def grant_for(saved_scenario, user = current_user)
    if saved_scenario.owner?(user) || saved_scenario.collaborator?(user)
      ScenarioGrant.for_role(scenario_id: saved_scenario.scenario_id, writable: true)
    elsif saved_scenario.viewer?(user)
      ScenarioGrant.for_role(scenario_id: saved_scenario.scenario_id, writable: false)
    end
  end

  def stamp_scenario_grant(saved_scenario)
    grant = grant_for(saved_scenario)
    issue_session_with_grant(current_user, grant) if grant
  end
end
