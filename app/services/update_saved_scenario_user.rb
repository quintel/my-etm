# frozen_string_literal: true

# Updates one or more user roles for a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single SavedScenarioUser/role_id pair OR an array of user params.
# Returns a ServiceResult with the updated SavedScenarioUser(s).
class UpdateSavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_or_object
  param :role_id_or_nil, default: proc { nil }
  option :user, optional: true

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    updated_users = []
    errors = {}

    ActiveRecord::Base.transaction do
      user_params_list.each do |user_params|
        result = update_single_user(user_params)
        if result.successful?
          updated_users << result.value
        else
          identifier = extract_identifier(user_params)
          errors[identifier] = result.errors
        end
      end
    end

    enqueue_current_scenario_sync(updated_users) if updated_users.any?
    enqueue_historical_sync(updated_users) if updated_users.any?

    return_result(updated_users, errors)
  end

  private

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

  def update_single_user(user_params)
    saved_scenario_user = if user_params[:saved_scenario_user]
      user_params[:saved_scenario_user]
    else
      find_saved_scenario_user(user_params)
    end

    identifier = extract_identifier(user_params, saved_scenario_user)

    unless saved_scenario_user
      return ServiceResult.failure({ identifier => [ "Saved scenario user not found" ] })
    end

    saved_scenario_user.role_id = user_params[:role_id]

    unless saved_scenario_user.valid?
      return ServiceResult.failure(saved_scenario_user.errors.full_messages)
    end

    unless saved_scenario_user.save
      return ServiceResult.failure(saved_scenario_user.errors.full_messages)
    end

    ServiceResult.success(saved_scenario_user)
  rescue StandardError => e
    Sentry.capture_exception(e)
    ServiceResult.failure([ e.message ])
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

  def extract_identifier(user_params, saved_scenario_user = nil)
    user_params[:id] || user_params[:user_id] || user_params[:user_email] || saved_scenario_user&.id
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

  def return_result(updated_users, errors)
    is_bulk = user_params_or_object.is_a?(Array)

    if is_bulk
      if errors.any?
        ServiceResult.failure(errors, value: updated_users)
      else
        ServiceResult.success(updated_users)
      end
    else
      updated_users.first ? ServiceResult.success(updated_users.first) : ServiceResult.failure(errors.values.first)
    end
  end
end
