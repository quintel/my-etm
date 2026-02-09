# frozen_string_literal: true

# Copies the roles of the preset API scenario to an API scenario.
#
#
# http_client      - The client used to communiate with ETEngine.
# scenario_id      - The ID of the ETEngine scenario to be setting the roles for
# saved_scenario   - Optional SavedScenario object to copy users from
#
# Returns a ServiceResult.
module ApiScenario::SetRoles
  module_function

  def call(http_client, scenario_id, saved_scenario: nil)
    params = { scenario: {} }

    if saved_scenario
      params[:scenario][:saved_scenario_users] = build_user_params(saved_scenario)
      params[:scenario][:metadata] = { saved_scenario_id: saved_scenario.id }
    else
      params[:scenario][:set_preset_roles] = true
    end

    http_client.put("/api/v3/scenarios/#{scenario_id}", params)

    ServiceResult.success
  rescue Faraday::UnprocessableEntityError => e
    ServiceResult.failure_from_unprocessable_entity(e)
  rescue Faraday::ClientError => e
    Sentry.capture_exception(e)
    ServiceResult.failure
  end

  def to_preset(http_client, scenario_id, saved_scenario: nil)
    call(http_client, scenario_id, saved_scenario: saved_scenario)
  end

  def build_user_params(saved_scenario)
    saved_scenario.saved_scenario_users.map do |user|
      {
        user_id: user.user_id,
        user_email: user.user_email,
        role_id: user.role_id
      }
    end
  end
end
