# frozen_string_literal: true

# Removes one or more users from a SavedScenario and synchronizes permissions to ETEngine.
# Syncs to current scenario synchronously, historical scenarios asynchronously.
#
# Accepts either a single SavedScenarioUser OR an array of user params.
# Returns a ServiceResult with the destroyed SavedScenarioUser(s).
class DestroySavedScenarioUser
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :user_params_or_object
  option :user, optional: true

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    destroyed_users = []
    errors = {}

    ActiveRecord::Base.transaction do
      user_params_list.each do |user_params|
        result = destroy_single_user(user_params)
        if result.successful?
          destroyed_users << result.value
        else
          identifier = extract_identifier(user_params)
          errors[identifier] = result.errors
        end
      end
    end

    enqueue_current_scenario_sync(destroyed_users) if destroyed_users.any?
    enqueue_historical_sync(destroyed_users) if destroyed_users.any?

    return_result(destroyed_users, errors)
  end

  private

  def normalize_params
    # Legacy single-user call: (http_client, saved_scenario, saved_scenario_user)
    if user_params_or_object.is_a?(SavedScenarioUser)
      [ { saved_scenario_user: user_params_or_object } ]
    # Bulk call: (http_client, saved_scenario, [{id: 1}, ...])
    else
      Array.wrap(user_params_or_object)
    end
  end

  def destroy_single_user(user_params)
    saved_scenario_user = if user_params[:saved_scenario_user]
      user_params[:saved_scenario_user]
    else
      find_saved_scenario_user(user_params)
    end

    identifier = extract_identifier(user_params, saved_scenario_user)

    unless saved_scenario_user
      return ServiceResult.failure({ identifier => [ "User not found" ] })
    end

    # Store the data we need before destroying
    user_data = {
      user_id: saved_scenario_user.user_id,
      user_email: saved_scenario_user.user_email,
      role: User::ROLES[saved_scenario_user.role_id],
      _destroyed_object: saved_scenario_user
    }

    unless saved_scenario_user.destroy
      return ServiceResult.failure(saved_scenario_user.errors.full_messages)
    end

    ServiceResult.success(user_data)
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

  def enqueue_current_scenario_sync(destroyed_users)
    user_id = user&.id || saved_scenario.users.first&.id
    return unless user_id

    scenario_users = destroyed_users.map do |user_data|
      {
        user_id: user_data[:user_id],
        user_email: user_data[:user_email],
        role: user_data[:role]
      }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: scenario_users,
          scenario_id: saved_scenario.scenario_id } ]
    )
  end

  def enqueue_historical_sync(destroyed_users)
    return if saved_scenario.scenario_id_history.blank?

    user_id = user&.id || saved_scenario.users.first&.id
    raise "No user found for SavedScenario #{saved_scenario.id}" unless user_id

    scenario_users = destroyed_users.map do |user_data|
      {
        user_id: user_data[:user_id],
        user_email: user_data[:user_email],
        role: user_data[:role]
      }
    end

    SavedScenarioUserCallbacksJob.perform_later(
      saved_scenario.id,
      user_id,
      saved_scenario.version.tag,
      [ { type: :destroy, scenario_users: scenario_users } ]
    )
  end

  def return_result(destroyed_users, errors)
    is_bulk = user_params_or_object.is_a?(Array)

    if is_bulk
      if errors.any?
        ServiceResult.failure(errors, value: destroyed_users)
      else
        ServiceResult.success(destroyed_users)
      end
    else
      if destroyed_users.first
        # Return the original ActiveRecord object for single-user case
        ServiceResult.success(destroyed_users.first[:_destroyed_object])
      else
        ServiceResult.failure(errors.values.first)
      end
    end
  end
end
