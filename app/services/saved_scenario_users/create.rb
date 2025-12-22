# frozen_string_literal: true

# Creates new users for a SavedScenario.
#
# Accepts bulk user creation - multiple users can be created in one call.
# The service will:
# 1. Create and validate SavedScenarioUser records
# 2. Save them to the database
# 3. Enqueue background callbacks to update ETEngine scenarios
# 4. Send invitation emails
#
# saved_scenario - The SavedScenario to add users to
# user_params_array - Array of hashes with user details:
#   - user_email: Email of the user to invite
#   - role_id: Role ID for the user
# invitee_name - Name of the user sending the invitation
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
    return ServiceResult.failure([ "No users provided" ]) if user_params_array.blank?

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

    # Return failure if ANY user failed (no partial success)
    return ServiceResult.failure(errors) unless errors.empty?

    # Enqueue background job to update ETEngine scenarios
    enqueue_callbacks(created_users) if created_users.any?

    # Send invitation emails
    send_invitation_emails(created_users)

    ServiceResult.success(created_users)
  end

  private

  def create_user(user_params)
    saved_scenario_user = SavedScenarioUser.new(
      user_params.merge(saved_scenario: saved_scenario)
    )

    return ServiceResult.failure(saved_scenario_user.errors.messages.keys) unless saved_scenario_user.valid?

    saved_scenario_user.couple_existing_user
    saved_scenario_user.save!

    ServiceResult.success(saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    ServiceResult.failure([ "duplicate" ])
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ e.message ])
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
