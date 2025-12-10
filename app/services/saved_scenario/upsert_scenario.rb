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
        enqueue_callbacks(ss.scenario_id_history.last,
          [ :unprotect ]) if ss.scenario_id_history.last
        return failure
      end

      ss.save
      saved_scenario.scenario_id = scenario_id
    end

    enqueue_callbacks

    ServiceResult.success(saved_scenario)
  end

  private

  def enqueue_callbacks(target_scenario_id = scenario_id,
    operations = [ :protect, :set_roles, :tag_version ])
    SavedScenarioCallbacksJob.perform_later(
      target_scenario_id,
      saved_scenario.users.first&.id,
      saved_scenario.version.tag,
      operations
    )
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
