# frozen_string_literal: true

# Updates the SavedScenario with params from the API.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be restored.
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::Update
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :params

  def call
    saved_scenario.tap do |ss|
      ss.attributes = params.except(:discarded, :scenario_id)

      if update_scenario?
        return update_scenario_failure unless update_scenario_result.successful?
      end

      if params.key?(:discarded)
        if params[:discarded]
          ss.discarded_at ||= Time.current
        else
          ss.discarded_at = nil
        end
      end

      return failure unless ss.valid?

      ss.save
    end

    ServiceResult.success(saved_scenario)
  end

  private


  # Safe updating of scenario_id for the API, checks if the id is new, or was
  # already part of the history
  def update_scenario?
    return false unless params[:scenario_id]
    return false if params[:scenario_id] == saved_scenario.scenario_id

    true
  end

  def update_scenario_result
    @update_scenario_result ||= begin
      if saved_scenario.contains?(params[:scenario_id])
        SavedScenario::Restore.call(http_client, saved_scenario, params[:scenario_id])
      else
        SavedScenario::UpsertScenario.call(http_client, saved_scenario, params[:scenario_id])
      end
    end
  end

  def update_scenario_failure
    ServiceResult.failure(update_scenario_result.errors)
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end
end
