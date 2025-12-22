# frozen_string_literal: true

# Performs ETEngine callbacks for SavedScenarioUsers.
#
# Applies user operations to both current and historical scenarios.
# Operations are expected to be an array of hashes with:
# - type: :create, :update, or :destroy
# - scenario_users: Array of user hashes
#
# Example:
#   operations = [
#     { type: :create, scenario_users: [{ user_email: 'test@example.com', role: 'scenario_viewer' }] },
#     { type: :update, scenario_users: [{ user_id: 123, role: 'scenario_owner' }] }
#   ]
#
# Returns a ServiceResult.
class SavedScenarioUsers::PerformEngineCallbacks
  extend Dry::Initializer
  include Service
  include SavedScenarioUsers::EngineOperations

  param :http_client
  param :saved_scenario
  option :operations, default: proc { [] }

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

    # Apply to current scenario first
    result = apply_to_current_scenario(operation_type, scenario_users)
    return unless result.successful?

    # Then apply to all historical scenarios
    apply_to_historical_scenarios(operation_type, scenario_users)
  end
end
