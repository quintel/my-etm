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

  # One Session on one Version. Built from and stored as a [version_tag, session_id, level] array
  Entry = Data.define(:tag, :session_id, :level) do
    def initialize(tag:, session_id:, level:)
      super(tag: tag.to_s, session_id: Integer(session_id), level: level.to_s)
    end

    def key = [ tag, session_id ]

    alias_method :to_a, :deconstruct

    def as_json(*) = to_a
  end
  private_constant :Entry

  attr_reader :entries

  # TEMPORARY(versioned-grant): entries stored before they named a Version have no tag, and are
  # dropped. Removed once every anchor holding one has outlived REFRESH_TTL.
  def initialize(entries = nil)
    @entries = Array(entries).filter_map { |entry| Entry.new(*entry) if entry.to_a.size == 3 }
  end

  def self.stronger(held, level)
    held == WRITE ? WRITE : level
  end

  # Adds [version_tag, session_id, level] entries as the most recently opened. A Session
  # named twice in one call keeps the stronger level
  def grant(entries)
    strongest(entries).reduce(self) { |access, entry| access.with(entry) }
  end

  def with(entry)
    self.class.new(without(entry.key).entries + [ entry ])
  end

  def without(key)
    self.class.new(entries.reject { |held| held.key == key })
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
    entries.map(&:tag).uniq.index_with { |tag| levels(tag).reject { |_, ids| ids.empty? } }
  end

  private

  def strongest(entries)
    entries.map { |entry| Entry.new(*entry) }.each_with_object({}) do |entry, strongest|
      held = strongest[entry.key]&.level
      strongest[entry.key] = entry.with(level: self.class.stronger(held, entry.level))
    end.values
  end

  def ids_at(tag, level)
    entries.filter_map { |entry| entry.session_id if entry.tag == tag && entry.level == level }
  end
end
