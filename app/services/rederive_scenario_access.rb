# frozen_string_literal: true

# Re-derives a ScenarioAccess from the user's current roles.
module RederiveScenarioAccess
  module_function

  def call(access, user_id)
    levels = levels_for(user_id, access.pairs.map(&:first))
    ScenarioAccess.new(access.pairs.filter_map { |id, _| [ id, levels[id] ] if levels[id] })
  end

  # The level the user's role gives on each of these Sessions that is a kept scenario's current Session
  def levels_for(user_id, session_ids)
    return {} if session_ids.empty?

    SavedScenario.kept.joins(:saved_scenario_users)
      .where(scenario_id: session_ids, saved_scenario_users: { user_id: })
      .pluck(:scenario_id, "saved_scenario_users.role_id")
      .each_with_object({}) do |(id, role_id), levels|
        levels[id] = ScenarioAccess.stronger(levels[id], User::Roles.access_level(role_id))
      end
  end
end
