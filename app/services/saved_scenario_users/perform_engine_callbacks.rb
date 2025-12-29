# frozen_string_literal: true

# Performs ETEngine callbacks for SavedScenarioUsers.
#
# Applies user operations to both current and historical scenarios.
# Operations are expected to be an array of hashes with:
# - type: :create, :update, or :destroy
# - scenario_users: Array of user hashes
#
# Returns a ServiceResult.
class SavedScenarioUsers::PerformEngineCallbacks
  extend Dry::Initializer
  include Service
  include SavedScenarioUsers::EngineOperations

  param :http_client
  param :saved_scenario
  option :operations, default: proc { [] }
  option :historical_only, default: proc { false }

  def call
    operations.each do |operation|
      perform_operation(operation)
    end
    ServiceResult.success
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure("Failed to perform engine callbacks: #{e.message}")
  end

  private

  def perform_operation(operation)
    operation_type = operation[:type] || operation["type"]
    scenario_users = operation[:scenario_users] || operation["scenario_users"]

    return if scenario_users.blank?

    unless historical_only
      result = apply_to_current_scenario(operation_type, scenario_users)

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
    end

    apply_to_historical_scenarios(operation_type, scenario_users)
  end
end
