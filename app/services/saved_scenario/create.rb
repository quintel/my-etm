# frozen_string_literal: true

# Creates a new SavedScenario based on the given scenario id.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be saved.
# settings        - Optional extra scenario data to be sent to ETEngine when
#                   creating the new API scenario.
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::Create
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario_params
  param :user

  def call
    return failure unless saved_scenario.valid?

    protect

    tag_new_version

    ServiceResult.success(saved_scenario)
  end

  private

  def saved_scenario
    @saved_scenario ||= SavedScenario.new(
      saved_scenario_params.merge(user: user)
    )
  end

  def scenario_id
    saved_scenario_params['scenario_id']
  end

  def protect
    ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
  end

  def tag_new_version
    ApiScenario::VersionTags::Create.call(http_client, scenario_id, '')
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
