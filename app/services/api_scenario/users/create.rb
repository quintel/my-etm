# frozen_string_literal: true

# Creates a new ScenarioUser for an ApiScenario
module ApiScenario
  module Users
    class Create
      include Service

      def initialize(http_client, scenario_id, scenario_user, invitation_args = nil)
        @http_client = http_client
        @scenario_id = scenario_id
        @scenario_user = scenario_user
        @invitation_args = invitation_args
      end

      def call
        ServiceResult.success(
          @http_client.post(
            "/api/v3/scenarios/#{@scenario_id}/users",
            { scenario_users: [ @scenario_user ] }
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
