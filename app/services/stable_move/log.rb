# frozen_string_literal: true

# The log of the stable moves: a JSON Lines file with one line per record a move or a revert
# handled, appended by every run. It is the history of the moves and the input of a revert.
#
# Each line holds the record_type and record_id, its status (moved, deleted, wiped, skipped or
# reverted), the reason, from_version and to_version, the scenario_ids and when it happened.
class StableMove::Log
  def initialize(path)
    @path = Pathname.new(path)
  end

  def entries
    return [] unless @path.exist?

    @path.each_line.filter_map { |line| JSON.parse(line) if line.present? }
  end

  def append(entries)
    at = Time.current.utc.iso8601

    @path.dirname.mkpath
    @path.open("a") { |file| entries.each { |entry| file.puts(JSON.generate(entry.merge("at" => at))) } }
  end

  # Public: The moved entries of the records still on the version they were moved to: the last
  # entry for each of them is a move to that version, not a revert from it.
  def in_place(version_tag)
    entries
      .select do |entry|
        (entry["status"] == "moved" && entry["to_version"] == version_tag) ||
          (entry["status"] == "reverted" && entry["from_version"] == version_tag)
      end
      .group_by { |entry| entry.values_at("record_type", "record_id") }
      .filter_map { |_, record_entries| record_entries.last if record_entries.last["status"] == "moved" }
  end
end
