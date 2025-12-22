# frozen_string_literal: true

module SavedScenarioUsers
  # Shared module for performing ETEngine API operations on SavedScenarioUsers
  # Provides methods to apply user operations to current and historical scenarios
  module EngineOperations
    # Applies user operations to the current scenario
    # @param operation [Symbol] :create, :update, or :destroy
    # @param scenario_users [Array<Hash>] Array of user hashes
    # @return [ServiceResult]
    def apply_to_current_scenario(operation, scenario_users)
      api_service_class(operation).call(
        http_client,
        saved_scenario.scenario_id,
        scenario_users
      )
    end

    # Applies user operations to all historical scenarios in background
    # @param operation [Symbol] :create, :update, or :destroy
    # @param scenario_users [Array<Hash>] Array of user hashes
    # @return [void]
    def apply_to_historical_scenarios(operation, scenario_users)
      saved_scenario.scenario_id_history.each do |scenario_id|
        api_service_class(operation).call(
          http_client,
          scenario_id,
          scenario_users
        )
      end
    end

    private

    def api_service_class(operation)
      ApiScenario::Users.const_get(operation.to_s.classify)
    end
  end
end
