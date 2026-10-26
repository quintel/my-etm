# frozen_string_literal: true

# Re-derives a ScenarioAccess from the user's current roles.
module RederiveScenarioAccess
  module_function

  def call(access, user_id)
    levels = current_levels(access, user_id)
    ScenarioAccess.new(access.pairs.filter_map { |id, _| [ id, levels[id] ] if levels[id] })
  end

  def current_levels(access, user_id)
    return {} if access.empty?

    SavedScenario.kept.joins(:saved_scenario_users)
      .where(scenario_id: access.pairs.map(&:first), saved_scenario_users: { user_id: })
      .pluck(:scenario_id, "saved_scenario_users.role_id")
      .each_with_object({}) do |(id, role_id), levels|
        levels[id] = ScenarioAccess.stronger(levels[id], User::Roles.access_level(role_id))
      end
  end
end
