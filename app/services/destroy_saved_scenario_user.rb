# frozen_string_literal: true

# Removes one or more users from a SavedScenario.
#
# Accepts either a single SavedScenarioUser OR an array of user params.
# Returns a ServiceResult for a single call, or a BulkResult for an array. Either way the value is
# the destroyed SavedScenarioUser.
class DestroySavedScenarioUser
  extend Dry::Initializer
  include Service
  include SavedScenarioUserLookup

  param :saved_scenario
  param :user_params_or_object

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    items = destroy_all(user_params_list)
    bulk? ? BulkResult.new(items) : items.first.to_service_result
  end

  private

  def bulk?
    user_params_or_object.is_a?(Array)
  end

  def destroy_all(user_params_list)
    user_params_list.each_with_index.map { |user_params, index| destroy_one(user_params, index) }
  end

  def destroy_one(user_params, index)
    identifier = extract_identifier(user_params)
    saved_scenario_user = user_params[:saved_scenario_user] || find_saved_scenario_user(user_params)

    unless saved_scenario_user
      return BulkResult::Item.error(
        index:, identifier:, code: :not_found, messages: [ "Saved scenario user not found" ]
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
    # Single member from the UI: (saved_scenario, saved_scenario_user)
    if user_params_or_object.is_a?(SavedScenarioUser)
      [ { saved_scenario_user: user_params_or_object } ]
    # Bulk call from the APIs: (saved_scenario, [{id: 1}, ...])
    else
      Array.wrap(user_params_or_object)
    end
  end
end
