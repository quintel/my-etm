# frozen_string_literal: true

# Points records moved to a stable version back to the version they came from, with the scenario ids
# they moved with. Those exist in both engines. A saved scenario saved on the stable version since
# has newer ids that exist only in the stable engine, so it gets back its logged ones, and the
# changes made since are lost. Deleted records and the wiped test data don't come back.
#
# version         - The tag of the version the records were moved to.
# log             - The StableMove::Log of the moves.
# saved_scenarios - Ids of the saved scenarios to revert; nil reverts every record in place.
# collections     - Ids of the collections to revert; nil reverts every record in place.
#
# Refuses, and reverts nothing, when the version doesn't exist, when a collection's own scenarios
# changed since the move, or when a collection and its saved scenarios would end on different
# versions.
#
# Returns a Hash with the number of records reverted and the saved scenarios whose scenario ids were
# set back.
class StableMove::Revert
  extend Dry::Initializer
  include Service

  param :version
  option :log
  option :saved_scenarios, optional: true
  option :collections, optional: true

  # Public: What #call would move back, as lines of text for a person to confirm. Refuses what #call
  # refuses before it changes anything.
  def summary
    in_place = start
    types = in_place.map { |entry| entry["record_type"] }.tally
    saved, collections = types.values_at("SavedScenario", "Collection").map(&:to_i)
    to = in_place.map { |entry| entry["from_version"] }.uniq
    lost = drifted(in_place).keys.map(&:id).sort

    [
      "Moving back from #{version}#{" to #{to.join(', ')}" if to.any?}",
      "",
      "Records that move back: #{in_place.size}",
      "   - #{saved} #{'saved scenario'.pluralize(saved)}",
      "   - #{collections} #{'collection'.pluralize(collections)}",
      "",
      "Saved scenarios that lose their changes on #{version}: #{lost.size}",
      *StableMove::Error.listing(lost)
    ]
  end

  def call
    in_place = start
    entries = []
    restored = []

    ActiveRecord::Base.transaction do
      in_place.group_by { |entry| [ entry["record_type"], entry["from_version"] ] }.each do |(type, from), group|
        ids = group.map { |entry| entry["record_id"] }
        type.constantize.where(id: ids, version: target)
          .update_all(version_id: Version.find_by!(tag: from).id)

        entries.concat(group.map do |entry|
          entry.except("at").merge(
            "status" => "reverted", "from_version" => version, "to_version" => from, "reason" => "revert"
          )
        end)
      end

      restored = restore_scenario_ids(in_place)
      check_collections!(in_place)
    end

    log.append(entries)
    { "reverted" => entries.size, "scenario_ids_restored" => restored }
  end

  private

  # Checks the version and the collections. Returns the log entries of the records to move back.
  def start
    if version.blank?
      raise StableMove::Error, "give the version the records moved to, like rails 'stable_move:revert[2027]'"
    end

    raise StableMove::Error, "there is no version #{version}. Give the one the records moved to" unless target

    log.in_place(version).select { |entry| selected?(entry) }.tap { |in_place| check_collection_scenarios!(in_place) }
  end

  def target
    @target ||= Version.find_by(tag: version)
  end

  def selected?(entry)
    return true if saved_scenarios.nil? && collections.nil?

    ids = entry["record_type"] == "Collection" ? collections : saved_scenarios
    ids.to_a.include?(entry["record_id"])
  end

  # The saved scenarios saved since the move, with the scenario ids they moved with.
  def drifted(in_place)
    logged = in_place.select { |entry| entry["record_type"] == "SavedScenario" }
      .to_h { |entry| [ entry["record_id"], entry["scenario_ids"] ] }

    SavedScenario.where(id: logged.keys).find_each.each_with_object({}) do |saved, drifted|
      drifted[saved] = logged[saved.id] unless saved.all_scenario_ids == logged[saved.id]
    end
  end

  # Sets back the scenario ids of the saved scenarios saved since the move. Returns their ids.
  def restore_scenario_ids(in_place)
    drifted(in_place).map do |saved, ids|
      saved.update_columns(scenario_id: ids.first, scenario_id_history: ids.drop(1).reverse)
      saved.id
    end.sort
  end

  def check_collection_scenarios!(in_place)
    changed = in_place.select { |entry| entry["record_type"] == "Collection" }.filter_map do |entry|
      collection = Collection.find_by(id: entry["record_id"])
      next unless collection

      entry["record_id"] if collection.scenarios.map(&:scenario_id).sort != entry["scenario_ids"].sort
    end

    return if changed.empty?

    raise StableMove::Error, [
      "collections have other scenarios than when they moved, which exist only on #{version}.",
      "",
      "Collections changed on #{version}: #{changed.size}",
      *StableMove::Error.listing(changed),
      "",
      "Leave them out with COLLECTIONS, or handle them by hand."
    ].join("\n")
  end

  def check_collections!(reverted)
    collection_ids = reverted.select { |entry| entry["record_type"] == "Collection" }.map { |entry| entry["record_id"] }
    saved_ids = reverted.select { |entry| entry["record_type"] == "SavedScenario" }.map { |entry| entry["record_id"] }
    affected = collection_ids + CollectionSavedScenario.where(saved_scenario_id: saved_ids).pluck(:collection_id)

    Collection.where(id: affected).includes(:saved_scenarios).find_each do |collection|
      next if collection.saved_scenarios.all? { |saved| saved.version_id == collection.version_id }

      raise StableMove::Error,
        "collection #{collection.id} would be on another version than its saved scenarios: " \
        "revert them together"
    end
  end
end
