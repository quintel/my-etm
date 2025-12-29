# frozen_string_literal: true

# Creates new users for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Returns a ServiceResult with the created SavedScenarioUsers.
class SavedScenarioUsers::Create
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_array
  param :invitee_name
  param :user

  def call
    return ServiceResult.failure("No users provided") if user_params_array.blank?

    created_users = []
    errors = {}

    user_params_array.each do |user_params|
      result = create_user(user_params)
      if result.successful?
        created_users << result.value
      else
        errors[user_params[:user_email]] = result.errors
      end
    end

    if created_users.any?
      enqueue_callbacks(created_users)
    end

    send_invitation_emails(created_users)

    if errors.any?
      ServiceResult.failure(errors, value: created_users)
    else
      ServiceResult.success(created_users)
    end
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    raise
  end

  private

  def create_user(user_params)
    saved_scenario_user = SavedScenarioUser.new(
      user_params.merge(saved_scenario: saved_scenario)
    )

    unless saved_scenario_user.valid?
      return ServiceResult.failure({ user_params[:user_email] => saved_scenario_user.errors.full_messages })
    end

    saved_scenario_user.couple_existing_user
    saved_scenario_user.save!

    ServiceResult.success(saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.failure({ user_params[:user_email] => [ "duplicate" ] })
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure({ user_params[:user_email] => [ e.message ] })
  end

  def sync_current_scenario!(created_users)
    scenario_users = created_users.map do |saved_scenario_user|
      {
        user_email: saved_scenario_user.email,
        role: User::ROLES[saved_scenario_user.role_id]
      }
    end

    result = ApiScenario::Users::Create.call(
      http_client,
      saved_scenario.scenario_id,
      scenario_users
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync users to ETEngine: #{result.errors}"
  end

  def enqueue_callbacks(created_users)
    scenario_users = created_users.map do |saved_scenario_user|
      {
        user_email: saved_scenario_user.email,
        role: User::ROLES[saved_scenario_user.role_id]
      }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user.id,
      saved_scenario.version.tag,
      [ { type: :create, scenario_users: scenario_users } ]
    )
  end

  def send_invitation_emails(created_users)
    created_users.each do |saved_scenario_user|
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
      Rails.logger.error("Failed to send invitation email to #{saved_scenario_user.email}: #{e.message}")
      Sentry.capture_exception(e)
    end
  end
end
