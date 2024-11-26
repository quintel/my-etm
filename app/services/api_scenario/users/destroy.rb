# frozen_string_literal: true

# Updates the role of a ScenarioUser for an ApiScenario
module ApiScenario
  module Users
    class Destroy
      include Service

      def initialize(http_client, scenario_id, scenario_user)
        @http_client = http_client
        @scenario_id = scenario_id
        @scenario_user = scenario_user
      end

      def call
        ServiceResult.success(
          @http_client.delete(
            "/api/v3/scenarios/#{@scenario_id}/users", scenario_users: [ @scenario_user ]
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
    end
  end
end
