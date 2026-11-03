# frozen_string_literal: true

# Removes the history up to the scenario from the provided SavedScenario.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be restored.
# user            - The user acting, who owns the engine token that unbinds dropped Sessions
#
# Returns a Dry::Monads::Result with the saved scenario.
class SavedScenario::Restore
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :saved_scenario
  param :scenario_id
  param :settings, default: proc { {} }
  option :user

  def call
    return Success(saved_scenario) unless saved_scenario.contains?(scenario_id)

    saved_scenario.tap do |ss|
      # The current Session leaves the scenario too, along with every later snapshot.
      dropped = [ ss.scenario_id ] + ss.restore_historical(scenario_id)
      return failure unless ss.valid?

      unbound = ApiScenario::SetBound.call(user, ss.version, dropped, false)
      return unbound if unbound.failure?

      ss.save
    end

    Success(saved_scenario)
  end

  private

  def failure
    Failure(saved_scenario.errors)
  end
end
