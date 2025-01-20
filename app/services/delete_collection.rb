# frozen_string_literal: true

# Removes a Collection from the database, along with all related scenarios,
# and instructs ETEngine that the scenarios no longer need to be protected.
#
# collection - A Collection record.
#
# Returns a ServiceResult.
DeleteCollection = lambda do |http_client, collection|
  scenario_ids = collection.scenarios.pluck(:scenario_id)

  collection.destroy
  scenario_ids.each { |id| SetAPIScenarioCompatibility.dont_keep_compatible(http_client, id) }

  ServiceResult.success
end
