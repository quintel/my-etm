# frozen_string_literal: true

# Updates one or more user roles for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single SavedScenarioUser/role_id pair OR an array of user params.
# Returns a ServiceResult for a single call, or a BulkResult for an array.
class UpdateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_or_object
  param :role_id_or_nil, default: proc { nil }
  option :user, optional: true
  # TODO: drop and always skip once v1 and v3 retire; they rely on ETEngine's scenario_users check.
  option :sync_to_engine, default: proc { true }

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    items = update_all(user_params_list)
    updated_users = items.select(&:ok?).map(&:value)

    if sync_to_engine && updated_users.any?
      enqueue_current_scenario_sync(updated_users)
      enqueue_historical_sync(updated_users)
    end

    bulk? ? BulkResult.new(items) : items.first.to_service_result
  end

  private

  def bulk?
    user_params_or_object.is_a?(Array)
  end

  def update_all(user_params_list)
    ActiveRecord::Base.transaction do
      user_params_list.each_with_index.map { |user_params, index| update_one(user_params, index) }
    end
  end

  def update_one(user_params, index)
    identifier = extract_identifier(user_params)
    saved_scenario_user = user_params[:saved_scenario_user] || find_saved_scenario_user(user_params)

    unless saved_scenario_user
      return BulkResult::Item.error(
        index:, identifier:, code: :not_found, messages: [ "Saved scenario user not found" ]
      )
    end

    saved_scenario_user.role_id = user_params[:role_id]

    unless saved_scenario_user.save
      return BulkResult::Item.invalid(index:, identifier:, record: saved_scenario_user)
    end

    BulkResult::Item.ok(index:, identifier:, value: saved_scenario_user)
  rescue StandardError => e
    Sentry.capture_exception(e)
    BulkResult::Item.error(index:, identifier:, code: :internal_error, messages: [ e.message ])
  end

  def normalize_params
    # Legacy single-user call: (http_client, saved_scenario, saved_scenario_user, role_id)
    if user_params_or_object.is_a?(SavedScenarioUser)
      [ {
        saved_scenario_user: user_params_or_object,
        role_id: role_id_or_nil
      } ]
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

  def enqueue_current_scenario_sync(updated_users)
    user_id = user&.id || saved_scenario.users.first&.id
    return unless user_id

    scenario_users = updated_users.map do |u|
      { user_id: u.user_id, role: User::ROLES[u.role_id] }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :update, scenario_users: scenario_users, scenario_id: saved_scenario.scenario_id } ]
    )
  end

  def enqueue_historical_sync(updated_users)
    return if saved_scenario.scenario_id_history.blank?

    user_id = user&.id || saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    scenario_users = updated_users.map do |u|
      { user_id: u.user_id, role: User::ROLES[u.role_id] }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :update, scenario_users: scenario_users } ]
    )
  end
end
