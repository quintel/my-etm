# frozen_string_literal: true

# Creates ScenarioUser(s) for an ApiScenario
# Expects scenario_users to be an array
module ApiScenario
  module Users
    class Create
      include Service

      def initialize(http_client, scenario_id, scenario_users, invitation_args = nil)
        @http_client = http_client
        @scenario_id = scenario_id
        @scenario_users = scenario_users
        @invitation_args = invitation_args
      end

      def call
        ServiceResult.success(
          @http_client.post(
            "/api/v3/scenarios/#{@scenario_id}/users",
            { scenario_users: @scenario_users }
          ).body
        )
      rescue Faraday::ResourceNotFound
        ServiceResult.failure("Scenario not found")
      rescue Faraday::UnprocessableEntityError => e
        ServiceResult.single_failure_from_unprocessable_entity_on_multiple_objects(e)
      rescue Faraday::Error => e
        Sentry.capture_exception(e)
        ServiceResult.failure("Failed to create scenario user: #{e.message}")
      end
    end
  end
end
