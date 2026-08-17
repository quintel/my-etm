# frozen_string_literal: true

# Creates one or more users for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single user params hash or an array of user params.
# Returns a ServiceResult for a single call, or a BulkResult for an array.
class CreateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :invitee_name
  param :user_params_or_array
  option :user, optional: true
  # TODO: drop and always skip once v1 and v3 retire; they rely on ETEngine's scenario_users check.
  option :sync_to_engine, default: proc { true }

  def call
    user_params_list = Array.wrap(user_params_or_array)
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    items = create_all(user_params_list)
    created_users = items.select(&:ok?).map(&:value)

    if sync_to_engine && created_users.any?
      enqueue_current_scenario_sync(created_users)
      enqueue_historical_sync(created_users)
    end

    send_invitation_emails(created_users)

    bulk? ? BulkResult.new(items) : items.first.to_service_result
  end

  private

  def bulk?
    user_params_or_array.is_a?(Array)
  end

  def create_all(user_params_list)
    ActiveRecord::Base.transaction do
      user_params_list.each_with_index.map { |user_params, index| create_one(user_params, index) }
    end
  end

  def create_one(user_params, index)
    identifier = user_params[:user_email] || user_params["user_email"]

    if unknown_user?(user_params)
      return BulkResult::Item.error(
        index:, identifier:, code: :not_found, messages: [ "User not found" ]
      )
    end

    saved_scenario_user = SavedScenarioUser.new(user_params.merge(saved_scenario: saved_scenario))

    unless saved_scenario_user.valid?
      return BulkResult::Item.invalid(index:, identifier:, record: saved_scenario_user)
    end

    saved_scenario_user.couple_existing_user
    saved_scenario_user.save!

    BulkResult::Item.ok(index:, identifier:, value: saved_scenario_user)
  rescue ActiveRecord::RecordNotUnique
    BulkResult::Item.error(index:, identifier:, code: :validation_failed, messages: [ "duplicate" ])
  rescue StandardError => e
    Sentry.capture_exception(e)
    BulkResult::Item.error(index:, identifier:, code: :internal_error, messages: [ e.message ])
  end

  # There is no foreign key on saved_scenario_users.user_id, so an unknown id would otherwise be
  # saved as an orphan membership.
  def unknown_user?(user_params)
    user_id = user_params[:user_id] || user_params["user_id"]

    user_id.present? && !User.exists?(id: user_id)
  end

  def enqueue_current_scenario_sync(created_users)
    user_id = user&.id || saved_scenario.users.first&.id
    return unless user_id

    scenario_users = created_users.map do |u|
      { user_email: u.email, role: User::ROLES[u.role_id] }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :create, scenario_users: scenario_users, scenario_id: saved_scenario.scenario_id } ]
    )
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
      ).deliver_later(queue: :mailers)
    rescue StandardError => e
      Rails.logger.error("Failed to send invitation email to #{saved_scenario_user.email}: #{e.message}")
      Sentry.capture_exception(e)
    end
  end
end
