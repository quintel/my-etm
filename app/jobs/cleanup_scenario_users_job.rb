# frozen_string_literal: true

# Cleans up zombie ScenarioUsers in ETEngine when a SavedScenario is discarded.
# Deletes all ScenarioUsers for the given scenario IDs (both current and historical).
class CleanupScenarioUsersJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff
  sidekiq_retry_in do |count|
    [ 30, 120, 600 ][count]
  end

  sidekiq_options retry: 3

  retry_on Faraday::Error, wait: :exponentially_longer, attempts: 3

  def perform(user_id, version_id, scenario_ids)
    user = User.find(user_id)
    version = Version.find(version_id)
    http_client = MyEtm::Auth.engine_client(user, version)

    scenario_ids.each do |scenario_id|
      delete_scenario_users(http_client, scenario_id)
    end
  end

  private

  def delete_scenario_users(http_client, scenario_id)
    response = http_client.delete("/api/v3/scenarios/#{scenario_id}/users")

    return if response.success?

    Sentry.capture_message(
      "Failed to cleanup ScenarioUsers for scenario #{scenario_id}: #{response.body}",
      level: :warning
    )
  rescue Faraday::ResourceNotFound
    # Scenario already deleted - expected edge case
  rescue StandardError => e
    Sentry.capture_exception(e)
    raise
  end
end
