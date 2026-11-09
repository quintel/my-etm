# frozen_string_literal: true

# Re-derives a ScenarioAccess from the user's current roles.
module RederiveScenarioAccess
  module_function

  def call(access, user_id)
    levels = levels_for(user_id, access.entries.map(&:session_id))

    ScenarioAccess.new(access.entries.filter_map do |entry|
      entry.with(level: levels[entry.key]) if levels[entry.key]
    end)
  end

  # The level the user's role gives on each of these Sessions that is a kept scenario's current
  # Session, keyed by that scenario's [version_tag, session_id]
  def levels_for(user_id, session_ids)
    return {} if session_ids.empty?

    SavedScenario.kept.joins(:saved_scenario_users, :version)
      .where(scenario_id: session_ids, saved_scenario_users: { user_id: })
      .pluck("versions.tag", :scenario_id, "saved_scenario_users.role_id")
      .each_with_object({}) do |(tag, id, role_id), levels|
        levels[[ tag, id ]] = ScenarioAccess.stronger(levels[[ tag, id ]], User::Roles.access_level(role_id))
      end
  end
end
