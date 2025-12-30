# frozen_string_literal: true

# Enqueues ETEngine callbacks after SavedScenarioUsers are created/updated/destroyed.
# Processes both current and historical scenarios asynchronously to avoid circular dependencies.
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

    operations.each do |operation|
      perform_operation(http_client, saved_scenario, operation)
    end
  rescue StandardError => e
    Sentry.capture_exception(e)
    Rails.logger.error("Failed to perform engine callbacks: #{e.message}")
    raise
  end

  private

  def perform_operation(http_client, saved_scenario, operation)
    operation_type = operation[:type] || operation["type"]
    scenario_users = operation[:scenario_users] || operation["scenario_users"]

    return if scenario_users.blank?

    # Apply to current scenario
    result = apply_to_scenario(http_client, saved_scenario.scenario_id, operation_type,
      scenario_users)

    unless result.successful?
      Rails.logger.error(
        "Failed to #{operation_type} users on current scenario #{saved_scenario.scenario_id}: #{result.errors}"
      )
      Sentry.capture_message(
        "SavedScenarioUserCallbacks failed for current scenario",
        extra: {
          saved_scenario_id: saved_scenario.id,
          scenario_id: saved_scenario.scenario_id,
          operation: operation_type,
          errors: result.errors
        }
      )
      return
    end

    # Apply to historical scenarios
    saved_scenario.scenario_id_history.each do |scenario_id|
      result = apply_to_scenario(http_client, scenario_id, operation_type, scenario_users)

      unless result.successful?
        Rails.logger.warn(
          "Failed to #{operation_type} users on historical scenario #{scenario_id}: #{result.errors}"
        )
      end
    end
  end

  def apply_to_scenario(http_client, scenario_id, operation_type, scenario_users)
    api_service_class = ApiScenario::Users.const_get(operation_type.to_s.classify)
    api_service_class.call(http_client, scenario_id, scenario_users)
  end
end
