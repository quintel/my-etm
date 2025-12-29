# frozen_string_literal: true

# Removes a user from a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Returns a ServiceResult.
class DestroySavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :saved_scenario_user

  def call
    ActiveRecord::Base.transaction do
      sync_current_scenario!

      unless saved_scenario_user.destroy
        return ServiceResult.failure(saved_scenario_user.errors.map(&:type))
      end

      enqueue_historical_sync
    end

    ServiceResult.success(saved_scenario_user)
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ "sync_failed" ])
  end

  private

  def api_user_params
    @api_user_params ||= {
      user_id: saved_scenario_user.user_id,
      user_email: saved_scenario_user.user_email,
      role: User::Roles.name_for(saved_scenario_user.role_id)
    }
  end

  def sync_current_scenario!
    result = ApiScenario::Users::Destroy.call(
      http_client,
      saved_scenario.scenario_id,
      api_user_params
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync user deletion to ETEngine: #{result.errors}"
  end

  def enqueue_historical_sync
    return if saved_scenario.scenario_id_history.blank?

    user_id = saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: [ api_user_params ] } ]
    )
  end
end
