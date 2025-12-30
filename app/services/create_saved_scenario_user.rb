# frozen_string_literal: true

# Creates one or more users for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single user params hash or an array of user params.
# Returns a ServiceResult with the resulting SavedScenarioUser(s).
class CreateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :invitee_name
  param :user_params_or_array
  option :user, optional: true

  def call
    user_params_list = Array.wrap(user_params_or_array)
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    created_users = []
    errors = {}

    ActiveRecord::Base.transaction do
      user_params_list.each do |user_params|
        result = create_single_user(user_params)
        if result.successful?
          created_users << result.value
        else
          errors[user_params[:user_email] || user_params["user_email"]] = result.errors
        end
      end

      sync_current_scenario!(created_users) if created_users.any?
    end

    enqueue_historical_sync(created_users) if created_users.any?
    send_invitation_emails(created_users)

    return_result(created_users, errors)
  rescue MyEtm::Auth::SyncError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ "sync_failed" ])
  end

  private

  def create_single_user(user_params)
    saved_scenario_user = SavedScenarioUser.new(
      user_params.merge(saved_scenario: saved_scenario)
    )

    unless saved_scenario_user.valid?
      return ServiceResult.failure(saved_scenario_user.errors.messages.keys)
    end

    saved_scenario_user.couple_existing_user
    saved_scenario_user.save!

    ServiceResult.success(saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.failure([ "duplicate" ])
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ e.message ])
  end

  def sync_current_scenario!(created_users)
    scenario_users = created_users.map do |user|
      { user_email: user.email, role: User::ROLES[user.role_id] }
    end

    result = ApiScenario::Users::Create.call(
      http_client,
      saved_scenario.scenario_id,
      scenario_users
    )

    return if result.successful?

    raise MyEtm::Auth::SyncError, "Failed to sync users to ETEngine: #{result.errors}"
  end

  def enqueue_historical_sync(created_users)
    return if saved_scenario.scenario_id_history.blank?

    user_id = user&.id || saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    scenario_users = created_users.map do |u|
      { user_email: u.email, role: User::ROLES[u.role_id] }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
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

  def return_result(created_users, errors)
    is_bulk = user_params_or_array.is_a?(Array)

    if is_bulk
      if errors.any?
        ServiceResult.failure(errors, value: created_users)
      else
        ServiceResult.success(created_users)
      end
    else
      created_users.first ? ServiceResult.success(created_users.first) : ServiceResult.failure(errors.values.first)
    end
  end
end
