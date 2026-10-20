# frozen_string_literal: true

# The Sessions a browser may read or write, carried on its access cookie as a `scenario_access` claim.
# Held on the anchor token as ordered [session_id, level] pairs, least recently opened first, so
# the oldest can be evicted when the token outgrows TOKEN_BUDGET
class ScenarioAccess
  READ = "read"
  WRITE = "write"
  CLAIM = "scenario_access"

  # Bytes allowed for the whole access JWT: two sessions (beta and production) must share one 8 KB
  # header. Holds ~140 seven-digit Session IDs at a 10-entry audience (assumes three versions * 3 apps
  # + myetm). Note that increasing the length of the ids will decrease the limit as well
  TOKEN_BUDGET = 3_000

  attr_reader :pairs

  def initialize(pairs = nil)
    @pairs = Array(pairs).map { |id, level| [ Integer(id), level.to_s ] }
  end

  # The access level a user's role gives them on a saved scenario, or nil without a role or once discarded
  def self.level_for(saved_scenario, user)
    return if saved_scenario.discarded?

    role_id = saved_scenario.saved_scenario_users.find_by(user_id: user.id)&.role_id
    level_of(role_id) if role_id
  end

  def self.level_of(role_id)
    role_id >= User::Roles.index_of(:scenario_collaborator) ? WRITE : READ
  end

  # The kept scenarios a user holds a role on, joined to that role
  def self.roles_of(user_id)
    SavedScenario.kept.joins(:saved_scenario_users).where(saved_scenario_users: { user_id: })
  end

  # Keeps the entries for a kept scenario's current Session the user still has a role on
  def rederived_for(user_id)
    levels = current_levels(user_id)
    self.class.new(pairs.filter_map { |id, _| [ id, levels[id] ] if levels[id] })
  end

  # Adds [session_id, level] entries as the most recently opened. A Session
  # named twice in one call keeps the stronger level
  def grant(entries)
    strongest(entries).reduce(self) { |access, (id, level)| access.with(id, level) }
  end

  def with(id, level)
    self.class.new(without(id).pairs + [ [ id, level ] ])
  end

  def without(id)
    self.class.new(pairs.reject { |held, _| held == id })
  end

  def without_oldest
    self.class.new(pairs.drop(1))
  end

  def empty?
    pairs.empty?
  end

  def as_claim
    { WRITE => ids_at(WRITE), READ => ids_at(READ) }
  end

  private

  def strongest(entries)
    entries.each_with_object({}) do |(id, level), levels|
      id = Integer(id)
      levels[id] = stronger(levels[id], level.to_s)
    end
  end

  def current_levels(user_id)
    return {} if empty?

    self.class.roles_of(user_id).where(scenario_id: pairs.map(&:first))
      .pluck(:scenario_id, "saved_scenario_users.role_id")
      .each_with_object({}) do |(id, role_id), levels|
        levels[id] = stronger(levels[id], self.class.level_of(role_id))
      end
  end

  def stronger(held, level)
    held == WRITE ? WRITE : level
  end

  def ids_at(level)
    pairs.filter_map { |id, held| id if held == level }
  end
end
