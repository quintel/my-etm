# frozen_string_literal: true

# Creates a new user for a SavedScenario based on the given existing saved_scenario_id and
# then adds it to the current API scenario and all the old API scenarios in the history.
#
# saved_scenario  - The scenario to be updated
# invitee_name    - The name of the user inviting this user.
# settings        - Settings that contain info for the new user
#
#
# Returns a ServiceResult with the resulting SavedScenarioUser.
class CreateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :invitee_name
  param :settings, default: proc { {} }

  def call
    return failure unless saved_scenario_user.valid?
    saved_scenario_user.couple_existing_user

    return api_response_invite if invite_failure?
    return historical_scenarios_result if historical_scenarios_result.failure?

    saved_scenario_user.save

    ServiceResult.success(saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.failure("duplicate")
  end

  private

  def saved_scenario_user
    @saved_scenario_user ||= SavedScenarioUser.new(
      settings.merge(saved_scenario: saved_scenario)
    )
  end

  def failure
    ServiceResult.failure(saved_scenario_user.errors.messages.keys)
  end

  def api_user_params
    @api_user_params ||= {
      user_id: saved_scenario_user.user_id,
      user_email: saved_scenario_user.user_email,
      role: saved_scenario_user.role
    }
  end

  # Create the user in the engine and send an invite
  # TODO: send invite from my-etm!!
  def api_response_invite
    @api_response_invite ||= ApiScenario::Users::Create.call(
      http_client,
      saved_scenario.scenario_id,
      api_user_params,
      {
        invite: true,
        user_name: invitee_name,
        id: saved_scenario.id,
        title: saved_scenario.title
      }
    )
  end

  def invite_failure?
    api_response_invite.failure?
  end

  # Update historical scenarios. If one fails, just move on to the next
  def api_response_historical_scenarios
    saved_scenario.scenario_id_history.each do |scenario_id|
      ApiScenario::Users::Create.call(
        http_client, scenario_id, api_user_params
      )
    end

    ServiceResult.success
  end

  def historical_scenarios_result
    @historical_scenarios_result = api_response_historical_scenarios
  end
end
