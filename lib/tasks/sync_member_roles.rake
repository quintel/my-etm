# frozen_string_literal: true

# TEMPORARY(scenario-users): repairs ScenarioUser roles that missed a sync from MyETM. Delete this
# file once ETEngine retires scenario_users.
module SessionMemberRoleSync
  module_function

  def shared_saved_scenarios
    shared = SavedScenarioUser.group(:saved_scenario_id).having("COUNT(*) > 1").select(:saved_scenario_id)
    SavedScenario.where(id: shared).includes(:version, saved_scenario_users: :user)
  end

  # Only the current Session: older versions are not repaired. Owners go first so ETEngine's
  # last-owner guard never refuses a demotion.
  def sync(client, saved_scenario, apply:)
    rows = client.get("/api/v3/scenarios/#{saved_scenario.scenario_id}/users").body

    saved_scenario.saved_scenario_users.sort_by { |member| -member.role_id }.filter_map do |member|
      sync_member(client, saved_scenario, member, rows, apply)
    end
  rescue Faraday::Error => e
    [ line(saved_scenario, nil, nil, "failed: #{e.response_status || e.class.name}") ]
  end

  def sync_member(client, saved_scenario, member, rows, apply)
    row = rows.find { |candidate| same_person?(candidate, member) }
    return line(saved_scenario, member, nil, "missing") unless row
    return if User::ROLES.key(row["role"].to_sym) == member.role_id

    action = apply ? update_role(client, saved_scenario.scenario_id, row, member) : "dry run"
    line(saved_scenario, member, row["role"], action)
  end

  # A member coupled in MyETM may still be pending by email in ETEngine.
  def same_person?(row, member)
    return row["user_id"] == member.user_id if row["user_id"] && member.user_id

    row["user_email"].present? && row["user_email"].casecmp?(member.email)
  end

  def update_role(client, session_id, row, member)
    result = ApiScenario::Users::Update.call(
      client, session_id, [ { id: row["id"], role: User::ROLES[member.role_id] } ]
    )
    result.successful? ? "updated" : "failed: #{result.errors.join(', ')}"
  end

  def line(saved_scenario, member, from, action)
    change = member && "#{member.email} #{short_role(from) || 'none'} -> #{short_role(User::ROLES[member.role_id])} "
    "ss=#{saved_scenario.id} session=#{saved_scenario.scenario_id} #{change}[#{action}]"
  end

  def short_role(role)
    role&.to_s&.delete_prefix("scenario_")
  end
end

namespace :scenarios do
  desc "Set ScenarioUsers on the current Session of shared saved scenarios to the member's role " \
       "in MyETM, where ETEngine holds a different one. Dry run unless APPLY=1. " \
       "Usage: rails scenarios:sync_member_roles [APPLY=1]"
  task sync_member_roles: :environment do
    apply = ENV["APPLY"] == "1"

    SessionMemberRoleSync.shared_saved_scenarios.find_each do |saved_scenario|
      client = MyEtm::Auth.engine_client(User.robot, saved_scenario.version, scenario: nil)
      SessionMemberRoleSync.sync(client, saved_scenario, apply:).each { |line| puts line }
    end
  end
end
