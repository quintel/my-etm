# frozen_string_literal: true

# Removes one or more users from a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single SavedScenarioUser OR an array of user params.
# Returns a ServiceResult for a single call, or a BulkResult for an array. Either way the value is
# the destroyed SavedScenarioUser.
class DestroySavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_or_object
  option :user, optional: true
  # TODO: drop and always skip once v1 and v3 retire; they rely on ETEngine's scenario_users check.
  option :sync_to_engine, default: proc { true }

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    items = destroy_all(user_params_list)
    destroyed_users = items.select(&:ok?).map(&:value)

    if sync_to_engine && destroyed_users.any?
      enqueue_current_scenario_sync(destroyed_users)
      enqueue_historical_sync(destroyed_users)
    end

    bulk? ? BulkResult.new(items) : items.first.to_service_result
  end

  private

  def bulk?
    user_params_or_object.is_a?(Array)
  end

  def destroy_all(user_params_list)
    ActiveRecord::Base.transaction do
      user_params_list.each_with_index.map { |user_params, index| destroy_one(user_params, index) }
    end
  end

  def destroy_one(user_params, index)
    identifier = extract_identifier(user_params)
    saved_scenario_user = user_params[:saved_scenario_user] || find_saved_scenario_user(user_params)

    unless saved_scenario_user
      return BulkResult::Item.error(
        index:, identifier:, code: :not_found, messages: [ "User not found" ]
      )
    end

    unless saved_scenario_user.destroy
      return BulkResult::Item.invalid(index:, identifier:, record: saved_scenario_user)
    end

    BulkResult::Item.ok(index:, identifier:, value: saved_scenario_user)
  rescue StandardError => e
    Sentry.capture_exception(e)
    BulkResult::Item.error(index:, identifier:, code: :internal_error, messages: [ e.message ])
  end

  def normalize_params
    # Legacy single-user call: (http_client, saved_scenario, saved_scenario_user)
    if user_params_or_object.is_a?(SavedScenarioUser)
      [ { saved_scenario_user: user_params_or_object } ]
    # Bulk call: (http_client, saved_scenario, [{id: 1}, ...])
    else
      Array.wrap(user_params_or_object)
    end
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

  def extract_identifier(user_params)
    user_params[:id] || user_params[:user_id] || user_params[:user_email]
  end

  def enqueue_current_scenario_sync(destroyed_users)
    user_id = user&.id || saved_scenario.users.first&.id
    return unless user_id

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: sync_payload(destroyed_users),
          scenario_id: saved_scenario.scenario_id } ]
    )
  end

  def enqueue_historical_sync(destroyed_users)
    return if saved_scenario.scenario_id_history.blank?

    user_id = user&.id || saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: sync_payload(destroyed_users) } ]
    )
  end

  def sync_payload(destroyed_users)
    destroyed_users.map do |saved_scenario_user|
      {
        user_id: saved_scenario_user.user_id,
        user_email: saved_scenario_user.user_email,
        role: User::ROLES[saved_scenario_user.role_id]
      }
    end
  end
end
