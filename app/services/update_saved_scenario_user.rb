# frozen_string_literal: true

# Updates one or more user roles for a SavedScenario
#
# Accepts either a single SavedScenarioUser/role_id pair OR an array of user params.
# Returns a ServiceResult for a single call, or a BulkResult for an array.
class UpdateSavedScenarioUser
  extend Dry::Initializer
  include Service
  include SavedScenarioUserLookup

  param :saved_scenario
  param :user_params_or_object
  param :role_id_or_nil, default: proc { nil }

  def call
    user_params_list = normalize_params
    return ServiceResult.failure("No users provided") if user_params_list.blank?

    items = update_all(user_params_list)
    bulk? ? BulkResult.new(items) : items.first.to_service_result
  end

  private

  def bulk?
    user_params_or_object.is_a?(Array)
  end

  # Ownership is granted before any is given up, so one batch can hand a scenario over and step
  # down without the last-owner guard refusing the step-down. Items are still reported in the
  # order they were submitted, whatever order they were applied in.
  def update_all(user_params_list)
    user_params_list
      .each_with_index
      .sort_by { |user_params, index| [ grants_ownership?(user_params) ? 0 : 1, index ] }
      .map { |user_params, index| update_one(user_params, index) }
      .sort_by(&:index)
  end

  def grants_ownership?(user_params)
    user_params[:role_id] == User::Roles.index_of(:scenario_owner)
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
    # Single member from the UI: (saved_scenario, saved_scenario_user, role_id)
    if user_params_or_object.is_a?(SavedScenarioUser)
      [ {
        saved_scenario_user: user_params_or_object,
        role_id: role_id_or_nil
      } ]
    else
      Array.wrap(user_params_or_object)
    end
  end
end
