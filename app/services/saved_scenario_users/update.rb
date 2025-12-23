# frozen_string_literal: true

# Updates roles for SavedScenario users.
#
# Accepts bulk user updates - multiple users can be updated in one call.
# The service will:
# 1. Find and update SavedScenarioUser records
# 2. Save them to the database
# 3. Enqueue background callbacks to update ETEngine scenarios
#
# saved_scenario - The SavedScenario containing the users
# user_params_array - Array of hashes with user details:
#   - id: SavedScenarioUser ID (optional)
#   - user_id: User ID (optional, alternative to id)
#   - user_email: User email (optional, alternative to id/user_id)
#   - role_id: New role ID for the user
# user - The user performing the update
#
# Returns a ServiceResult with the updated SavedScenarioUsers.
class SavedScenarioUsers::Update
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_array
  param :user

  def call
    return ServiceResult.failure([ "No users provided" ]) if user_params_array.blank?

    updated_users = []
    errors = {}

    user_params_array.each do |user_params|
      result = update_user(user_params)
      if result.successful?
        updated_users << result.value
      else
        identifier = user_params[:id] || user_params[:user_id] || user_params[:user_email]
        errors[identifier] = result.errors
      end
    end

    # Enqueue background job to update ETEngine scenarios for successful users
    enqueue_callbacks(updated_users) if updated_users.any?

    # Return partial success if some users failed
    if errors.any?
      ServiceResult.failure(errors, value: updated_users)
    else
      ServiceResult.success(updated_users)
    end
  end

  private

  def update_user(user_params)
    saved_scenario_user = find_saved_scenario_user(user_params)
    identifier = user_params[:id] || user_params[:user_id] || user_params[:user_email]

    unless saved_scenario_user
      return ServiceResult.failure({
        identifier => [ "Saved scenario user not found" ]
      })
    end

    saved_scenario_user.role_id = user_params[:role_id]

    unless saved_scenario_user.valid?
      return ServiceResult.failure({
        identifier => saved_scenario_user.errors.full_messages
      })
    end

    saved_scenario_user.save!

    ServiceResult.success(saved_scenario_user)
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure({
      identifier => [ e.message ]
    })
  end

  def find_saved_scenario_user(user_params)
    if user_params[:id]
      saved_scenario.saved_scenario_users.find_by(id: user_params[:id])
    elsif user_params[:user_id]
      saved_scenario.saved_scenario_users.find_by(user_id: user_params[:user_id])
    elsif user_params[:user_email]
      saved_scenario.saved_scenario_users.find_by(user_email: user_params[:user_email])
    end
  end

  def enqueue_callbacks(updated_users)
    scenario_users = updated_users.map do |saved_scenario_user|
      {
        user_id: saved_scenario_user.user_id,
        role: User::ROLES[saved_scenario_user.role_id]
      }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user.id,
      saved_scenario.version.tag,
      [ { type: :update, scenario_users: scenario_users } ]
    )
  end
end
