# frozen_string_literal: true

# Removes the history up to the scenario from the provided SavedScenario.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be restored.
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::Restore
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :scenario_id
  param :settings, default: proc { {} }

  def call
    saved_scenario.tap do |ss|
      discarded_scenarios = ss.restore_historical(scenario_id)

      return ServiceResult.success(saved_scenario) unless discarded_scenarios
      return failure unless ss.valid?

      discarded_scenarios.each { |id| unprotect(id) }

      ss.save
      saved_scenario.scenario_id = scenario_id
    end

    ServiceResult.success(saved_scenario)
  end

  private

  # TODO: remove version tags!

  def unprotect(scenario_id)
    ApiScenario::SetCompatibility.dont_keep_compatible(http_client, scenario_id)
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
