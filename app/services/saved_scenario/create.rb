# frozen_string_literal: true

# Creates a new SavedScenario based on the given scenario id.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be saved.
# settings        - Optional extra scenario data to be sent to ETEngine when
#                   creating the new API scenario.
#
# Returns a Dry::Monads::Result with the saved scenario. A failure carries the record's errors, or
# an [:upstream, messages] pair when ETEngine failed to bind the scenario's Session
class SavedScenario::Create
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :http_client
  param :saved_scenario_params
  param :user

  def call
    return failure unless saved_scenario.valid?
    return Failure([ :upstream, bind_result.errors ]) if bind_result.failure?

    # Sometimes we have to explicitly set the user again
    saved_scenario.user = user
    saved_scenario.save
    enqueue_callbacks

    Success(saved_scenario)
  end

  private

  def bind_result
    @bind_result ||= ApiScenario::SetBound.for_saved_scenario(user, saved_scenario, true)
  end

  def saved_scenario
    @saved_scenario ||= SavedScenario.new(saved_scenario_attrs)
  end

  def scenario_id
    saved_scenario.scenario_id
  end

  def saved_scenario_attrs
    attributes = saved_scenario_params.merge(
      user: user,
      private: saved_scenario_params.fetch(:private, user.private_scenarios)
    )
    attributes["version"] = version

    attributes
  end

  # Stable version tag
  def version
    Version.find_by(tag: saved_scenario_params["version"]) || Version.default
  end

  def enqueue_callbacks
    SavedScenarioCallbacksJob.perform_later(
      scenario_id,
      user.id,
      version.tag,
      [ :protect, :set_roles, :tag_version ],
      saved_scenario_id: saved_scenario.id
    )
  end

  def failure
    Failure(saved_scenario.errors)
  end
end
