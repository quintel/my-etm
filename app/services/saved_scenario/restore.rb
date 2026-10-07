# frozen_string_literal: true

# Removes the history up to the scenario from the provided SavedScenario.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be restored.
# user            - The user acting, who owns the engine token that unbinds dropped Sessions
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::Restore
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :scenario_id
  param :settings, default: proc { {} }
  option :user

  def call
    saved_scenario.tap do |ss|
      discarded_scenarios = ss.restore_historical(scenario_id)

      return ServiceResult.success(saved_scenario) if discarded_scenarios.empty?
      return failure unless ss.valid?

      unbound = ApiScenario::SetBound.call(user, ss.version, discarded_scenarios, false)
      return unbound if unbound.failure?

      discarded_scenarios.each { |id| unprotect(id) }

      ss.save
      saved_scenario.scenario_id = scenario_id
    end

    ServiceResult.success(saved_scenario)
  end

  private

  def unprotect(scenario_id)
    ApiScenario::SetCompatibility.dont_keep_compatible(http_client, scenario_id)
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
