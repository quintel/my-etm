# frozen_string_literal: true

# Creates a new user for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
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

    ActiveRecord::Base.transaction do
      sync_current_scenario!
      saved_scenario_user.save!
      send_invitation_email
      enqueue_historical_sync
    end

    ServiceResult.success(saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.failure("duplicate")
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ "sync_failed" ])
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

  def send_invitation_email
    ScenarioInvitationMailer.invite_user(
      saved_scenario_user.email,
      invitee_name,
      User::ROLES[saved_scenario_user.role_id],
      {
        id: saved_scenario.id,
        title: saved_scenario.title
      },
      name: saved_scenario_user.name
    ).deliver_now
  rescue StandardError => e
    Rails.logger.error("Failed to send invitation email: #{e.message}")
    Sentry.capture_exception(e)
  end

  def sync_current_scenario!
    result = ApiScenario::Users::Create.call(
      http_client, saved_scenario.scenario_id, api_user_params
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync user to ETEngine: #{result.errors}"
  end

  def enqueue_historical_sync
    return if saved_scenario.scenario_id_history.blank?

    user_id = saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :create, scenario_users: [ api_user_params ] } ]
    )
  end

  def api_user_params
    {
      user_email: saved_scenario_user.email,
      role: User::ROLES[saved_scenario_user.role_id]
    }
  end
end
