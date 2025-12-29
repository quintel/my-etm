# frozen_string_literal: true

# Updates a user's role for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Returns a ServiceResult.
class UpdateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :saved_scenario_user
  param :role_id

  def call
    saved_scenario_user.role_id = role_id
    return failure unless saved_scenario_user.valid?

    ActiveRecord::Base.transaction do
      sync_current_scenario!

      unless saved_scenario_user.save
        return failure
      end

      enqueue_historical_sync
    end

    ServiceResult.success(saved_scenario_user)
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ "sync_failed" ])
  end

  private

  def failure
    ServiceResult.failure(saved_scenario_user.errors.map(&:type))
  end

  def api_user_params
    @api_user_params ||= {
      user_id: saved_scenario_user.user_id,
      role: User::Roles.name_for(role_id)
    }
  end

  def sync_current_scenario!
    result = ApiScenario::Users::Update.call(
      http_client,
      saved_scenario.scenario_id,
      api_user_params
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync user update to ETEngine: #{result.errors}"
  end

  def enqueue_historical_sync
    return if saved_scenario.scenario_id_history.blank?

    user_id = saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :update, scenario_users: [ api_user_params ] } ]
    )
  end
end
