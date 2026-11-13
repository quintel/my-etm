# frozen_string_literal: true

# Removes a Collection from the database, along with all related scenarios,
# and instructs ETEngine that the scenarios no longer need to be protected.
#
# TEMPORARY(collection-sessions): Remove this once collections are fully  migrated to SavedScenarios.
# collections are migrated to SavedScenarios.
#
# http_client - A client for the collection's ETEngine.
# collection  - A Collection record.
#
# Returns a ServiceResult.
DeleteCollection = lambda do |http_client, collection|
  session_ids = collection.interpolated? ? collection.scenarios.pluck(:scenario_id) : []

  collection.destroy
  session_ids.each { |id| ApiScenario::SetCompatibility.dont_keep_compatible(http_client, id) }

  ServiceResult.success
end
