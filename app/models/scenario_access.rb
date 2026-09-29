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

  # The access level a user's role gives them on a saved scenario, or nil without a role
  def self.level_for(saved_scenario, user)
    role_id = saved_scenario.saved_scenario_users.find_by(user_id: user.id)&.role_id
    return unless role_id

    role_id >= User::Roles.index_of(:scenario_collaborator) ? WRITE : READ
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
      levels[id] = levels[id] == WRITE ? WRITE : level.to_s
    end
  end

  def ids_at(level)
    pairs.filter_map { |id, held| id if held == level }
  end
end
