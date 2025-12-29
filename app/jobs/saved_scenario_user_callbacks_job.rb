# frozen_string_literal: true

# Enqueues ETEngine callbacks after SavedScenarioUsers are created/updated/destroyed.
# Processes both current and historical scenarios asynchronously to avoid circular dependencies.
# Delegates to SavedScenarioUsers::PerformEngineCallbacks for the actual work.
class SavedScenarioUserCallbacksJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff: 30s, 2m, 10m, 1h, 5h
  sidekiq_retry_in do |count|
    [ 30, 120, 600, 3600, 18000 ][count]
  end

  sidekiq_options retry: 5

  # Retry on network errors and other transient failures
  retry_on Faraday::Error, wait: :exponentially_longer, attempts: 5

  # Retry on database record not found (e.g., if user/scenario was just created)
  retry_on ActiveRecord::RecordNotFound, wait: 2.seconds, attempts: 3

  def perform(saved_scenario_id, user_id, version_tag, operations)
    user = User.find(user_id)
    saved_scenario = SavedScenario.find(saved_scenario_id)
    version = Version.find_by(tag: version_tag) || Version.default
    http_client = MyEtm::Auth.engine_client(user, version)

    # Process ALL scenarios (current + historical) asynchronously
    SavedScenarioUsers::PerformEngineCallbacks.call(
      http_client,
      saved_scenario,
      operations: operations,
      historical_only: false
    )
  end
end
