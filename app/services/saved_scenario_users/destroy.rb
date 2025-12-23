# frozen_string_literal: true

# Destroys users from a SavedScenario.
#
# Accepts bulk user deletion - multiple users can be deleted in one call.
# The service will:
# 1. Find SavedScenarioUser records
# 2. Delete them from the database
# 3. Enqueue background callbacks to update ETEngine scenarios
#
# saved_scenario - The SavedScenario containing the users
# user_params_array - Array of hashes with user identifiers:
#   - id: SavedScenarioUser ID (optional)
#   - user_id: User ID (optional, alternative to id)
#   - user_email: User email (optional, alternative to id/user_id)
# user - The user performing the deletion
#
# Returns a ServiceResult with the destroyed SavedScenarioUsers.
class SavedScenarioUsers::Destroy
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_array
  param :user

  def call
    return ServiceResult.failure([ "No users provided" ]) if user_params_array.blank?

    destroyed_users = []
    errors = {}

    user_params_array.each do |user_params|
      result = destroy_user(user_params)
      if result.successful?
        destroyed_users << result.value
      else
        identifier = user_params[:id] || user_params[:user_id] || user_params[:user_email]
        errors[identifier] = result.errors
      end
    end

    # Enqueue background job to update ETEngine scenarios for successful users
    enqueue_callbacks(destroyed_users) if destroyed_users.any?

    # Return partial success if some users failed
    if errors.any?
      ServiceResult.failure(errors, value: destroyed_users)
    else
      ServiceResult.success(destroyed_users)
    end
  end

  private

  def destroy_user(user_params)
    saved_scenario_user = find_saved_scenario_user(user_params)
    unless saved_scenario_user
      identifier = user_params[:id] || user_params[:user_id] || user_params[:user_email]
      return ServiceResult.failure({ identifier => [ "User not found" ] })
    end

    # Store the data we need before destroying
    user_data = {
      user_id: saved_scenario_user.user_id,
      user_email: saved_scenario_user.user_email,
      role: User::ROLES[saved_scenario_user.role_id]
    }

    saved_scenario_user.destroy!

    ServiceResult.success(user_data)
  rescue StandardError => e
    Sentry.capture_exception(e)
    identifier = user_params[:id] || user_params[:user_id] || user_params[:user_email]
    ServiceResult.failure({ identifier => [ e.message ] })
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

  def enqueue_callbacks(destroyed_users)
    scenario_users = destroyed_users.map do |user_data|
      {
        user_id: user_data[:user_id],
        user_email: user_data[:user_email],
        role: user_data[:role]
      }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user.id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: scenario_users } ]
    )
  end
end
