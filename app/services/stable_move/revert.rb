# frozen_string_literal: true

# Points records moved to a stable version back to the version they came from. Their scenarios
# there were never changed, and their ids are the same in both engines, so only the version changes
# back. Deleted records and the wiped test data don't come back.
#
# version         - The tag of the version the records were moved to.
# log             - The StableMove::Log of the moves.
# saved_scenarios - Ids of the saved scenarios to revert; nil reverts every record in place.
# collections     - Ids of the collections to revert; nil reverts every record in place.
#
# A collection and its saved scenarios must end on one version, or nothing is reverted.
#
# Returns the number of records reverted.
class StableMove::Revert
  extend Dry::Initializer
  include Service

  param :version
  option :log
  option :saved_scenarios, optional: true
  option :collections, optional: true

  def call
    in_place = log.in_place(version).select { |entry| selected?(entry) }
    entries = []

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

      check_collections!(in_place)
    end

    log.append(entries)
    entries.size
  end

  private

  def selected?(entry)
    return true if saved_scenarios.nil? && collections.nil?

    ids = entry["record_type"] == "Collection" ? collections : saved_scenarios
    ids.to_a.include?(entry["record_id"])
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
