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

    # Sometimes we have to explicitly set the user again
    saved_scenario.user = user

    protect

    saved_scenario.save
    tag_new_version

    ServiceResult.success(saved_scenario)
  end

  private

  def saved_scenario
    @saved_scenario ||= SavedScenario.new(saved_scenario_attrs)
  end

  def scenario_id
    saved_scenario.scenario_id
  end

  def saved_scenario_attrs
    attributes = saved_scenario_params.merge(
      user: user,
      private: user.private_scenarios
    )
    attributes['version'] = version

    attributes
  end

  # Stable version tag
  def version
    Version.find_by(tag: saved_scenario_params['version']) || Version.default
  end

  def protect
    ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
  end

  # Version history in Etengine
  def tag_new_version
    ApiScenario::VersionTags::Create.call(http_client, scenario_id, '')
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
