# frozen_string_literal: true

# Adds the current scenario to the provided SavedScenario, and adding the old
# scenario to history.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be saved.
# settings        - Optional extra scenario data to be sent to ETEngine when
#                   creating the new API scenario.
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::UpsertScenario
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :scenario_id
  param :settings, default: proc { {} }

  def call
    saved_scenario.tap do |ss|
      ss.add_id_to_history(ss.scenario_id)
      ss.scenario_id = scenario_id

      unless ss.valid?
        unprotect
        return failure
      end

      protect

      set_roles

      tag_new_version

      ss.save
      saved_scenario.scenario_id = scenario_id
    end

    ServiceResult.success(saved_scenario)
  end

  private

  def protect
    ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
  end

  def unprotect
    ApiScenario::SetCompatibility.dont_keep_compatible(http_client, scenario_id)
  end

  def set_roles
    ApiScenario::SetRoles.to_preset(http_client, scenario_id)
  end

  def tag_new_version
    ApiScenario::VersionTags::Create.call(http_client, scenario_id, "")
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end

  # TODO: keep in ETModel
  # def api_scenario
  #   api_response.value
  # end

  # def api_response
  #   @api_response ||= CreateAPIScenario.call(http_client, settings.merge(scenario_id:))
  # end

  # def failure?
  #   api_response.failure?
  # end
end
