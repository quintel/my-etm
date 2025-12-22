# frozen_string_literal: true

# Updates the role of a ScenarioUser for an ApiScenario
module ApiScenario
  module Users
    class Destroy
      include Service

      def initialize(http_client, scenario_id, scenario_users)
        @http_client = http_client
        @scenario_id = scenario_id
        @scenario_users = normalize_to_array(scenario_users)
      end

      def call
        ServiceResult.success(
          @http_client.delete(
            "/api/v3/scenarios/#{@scenario_id}/users", scenario_users: @scenario_users
          ).body
        )
      rescue Faraday::ResourceNotFound
        ServiceResult.failure("Scenario not found")
      rescue Faraday::UnprocessableEntityError => e
        ServiceResult.single_failure_from_unprocessable_entity_on_multiple_objects(e)
      rescue Faraday::Error => e
        Sentry.capture_exception(e)
        ServiceResult.failure("Failed to destroy scenario user: #{e.message}")
      end

      private

      def normalize_to_array(scenario_users)
        scenario_users.is_a?(Array) ? scenario_users : [ scenario_users ]
      end
    end
  end
end
