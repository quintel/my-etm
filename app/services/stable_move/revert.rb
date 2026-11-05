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
# Refuses, and reverts nothing, when a collection's own scenarios changed since the move, or when a
# collection and its saved scenarios would end on different versions.
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

  def call
    in_place = log.in_place(version).select { |entry| selected?(entry) }
    check_collection_scenarios!(in_place)

    entries = []
    restored = []

    ActiveRecord::Base.transaction do
      in_place.group_by { |entry| [ entry["record_type"], entry["from_version"] ] }.each do |(type, from), group|
        ids = group.map { |entry| entry["record_id"] }
        type.constantize.where(id: ids, version: Version.find_by!(tag: version))
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

  def selected?(entry)
    return true if saved_scenarios.nil? && collections.nil?

    ids = entry["record_type"] == "Collection" ? collections : saved_scenarios
    ids.to_a.include?(entry["record_id"])
  end

  # Sets back the scenario ids of the saved scenarios saved since the move. Returns their ids.
  def restore_scenario_ids(in_place)
    logged = in_place.select { |entry| entry["record_type"] == "SavedScenario" }
      .to_h { |entry| [ entry["record_id"], entry["scenario_ids"] ] }

    SavedScenario.where(id: logged.keys).find_each.filter_map do |saved|
      ids = logged[saved.id]
      next if saved.all_scenario_ids == ids

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

    raise StableMove::Error,
      "Collections #{changed.join(', ')} have other scenarios than when they moved, which exist only on " \
      "#{version}. Leave them out with COLLECTIONS, or handle them by hand"
  end

  def check_collections!(reverted)
    collection_ids = reverted.select { |entry| entry["record_type"] == "Collection" }.map { |entry| entry["record_id"] }
    saved_ids = reverted.select { |entry| entry["record_type"] == "SavedScenario" }.map { |entry| entry["record_id"] }
    affected = collection_ids + CollectionSavedScenario.where(saved_scenario_id: saved_ids).pluck(:collection_id)

    Collection.where(id: affected).includes(:saved_scenarios).find_each do |collection|
      next if collection.saved_scenarios.all? { |saved| saved.version_id == collection.version_id }

      raise StableMove::Error,
        "Collection #{collection.id} would be on another version than its saved scenarios. " \
        "Revert them together"
    end
  end
end
