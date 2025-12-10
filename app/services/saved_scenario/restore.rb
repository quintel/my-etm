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

      return ServiceResult.success(saved_scenario) if discarded_scenarios.empty?
      return failure unless ss.valid?

      ss.save
      saved_scenario.scenario_id = scenario_id

      discarded_scenarios.each { |id| enqueue_unprotect(id) }
    end

    ServiceResult.success(saved_scenario)
  end

  private

  def enqueue_unprotect(scenario_id)
    SavedScenarioCallbacksJob.perform_later(
      scenario_id,
      saved_scenario.users.first&.id,
      saved_scenario.version.tag,
      [ :unprotect ]
    )
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
