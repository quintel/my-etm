# frozen_string_literal: true

# Updates the SavedScenario with params from the API.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be restored.
#
# Returns a Dry::Monads::Result with the saved scenario. A failure carries the record's errors, or
# a [:upstream, messages] pair when a service this update depends on is what failed.
class SavedScenario::Update
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

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

    Success(saved_scenario)
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

  # Tagged, because nothing the caller sent is at fault and the response says so with a 502.
  def update_scenario_failure
    Failure([ :upstream, update_scenario_result.errors ])
  end

  def failure
    Failure(saved_scenario.errors)
  end
end
