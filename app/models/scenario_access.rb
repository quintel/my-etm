# frozen_string_literal: true

# The Sessions a browser may read or write, carried on its access cookie as a `scenario_access` claim.
# Each Version numbers its Sessions separately, so every entry names its Version's tag. Held on the
# anchor token as ordered [version_tag, session_id, level] entries, least recently opened first, so
# the oldest can be evicted when the token outgrows TOKEN_BUDGET
class ScenarioAccess
  READ = "read"
  WRITE = "write"
  CLAIM = "scenario_access"

  # Bytes allowed for the whole access JWT: two sessions (beta and production) must share one 8 KB
  # header. Holds ~140 seven-digit Session IDs at a 10-entry audience (assumes three versions * 3 apps
  # + myetm).
  TOKEN_BUDGET = 3_000

  attr_reader :entries

  # Entries stored before they named a Version have no tag, and are dropped
  def initialize(entries = nil)
    @entries = Array(entries).filter_map do |entry|
      tag, id, level = entry
      [ tag.to_s, Integer(id), level.to_s ] if entry.size == 3
    end
  end

  def self.stronger(held, level)
    held == WRITE ? WRITE : level
  end

  # Adds [version_tag, session_id, level] entries as the most recently opened. A Session
  # named twice in one call keeps the stronger level
  def grant(entries)
    strongest(entries).reduce(self) { |access, ((tag, id), level)| access.with(tag, id, level) }
  end

  def with(tag, id, level)
    self.class.new(without(tag, id).entries + [ [ tag, id, level ] ])
  end

  def without(tag, id)
    self.class.new(entries.reject { |held_tag, held_id, _| held_tag == tag && held_id == id })
  end

  def without_oldest
    self.class.new(entries.drop(1))
  end

  def empty?
    entries.empty?
  end

  # The Session IDs held on one Version, by level
  def levels(tag)
    { WRITE => ids_at(tag, WRITE), READ => ids_at(tag, READ) }
  end

  # Each Version's levels, leaving out empty Versions and levels
  def as_claim
    entries.map(&:first).uniq.index_with { |tag| levels(tag).reject { |_, ids| ids.empty? } }
  end

  private

  def strongest(entries)
    entries.each_with_object({}) do |(tag, id, level), levels|
      key = [ tag.to_s, Integer(id) ]
      levels[key] = self.class.stronger(levels[key], level.to_s)
    end
  end

  def ids_at(tag, level)
    entries.filter_map { |held_tag, id, held| id if held_tag == tag && held == level }
  end
end
