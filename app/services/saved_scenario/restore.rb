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
    return ServiceResult.success(saved_scenario) unless saved_scenario.contains?(scenario_id)

    saved_scenario.tap do |ss|
      # The current Session leaves the scenario too, along with every later snapshot.
      dropped = [ ss.scenario_id ] + ss.restore_historical(scenario_id)
      return failure unless ss.valid?

      unbound = ApiScenario::SetBound.call(user, ss.version, dropped, false)
      return unbound if unbound.failure?

      dropped.each { |id| unprotect(id) }

      ss.save
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
