# frozen_string_literal: true

# Destroys users from a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
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
    return ServiceResult.failure("No users provided") if user_params_array.blank?

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

    if destroyed_users.any?
      enqueue_callbacks(destroyed_users)
    end

    if errors.any?
      ServiceResult.failure(errors, value: destroyed_users)
    else
      ServiceResult.success(destroyed_users)
    end
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    raise
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

  def sync_current_scenario!(destroyed_users)
    scenario_users = destroyed_users.map do |user_data|
      {
        user_id: user_data[:user_id],
        user_email: user_data[:user_email],
        role: user_data[:role]
      }
    end

    result = ApiScenario::Users::Destroy.call(
      http_client,
      saved_scenario.scenario_id,
      scenario_users
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync users to ETEngine: #{result.errors}"
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
