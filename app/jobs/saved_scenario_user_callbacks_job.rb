# frozen_string_literal: true

# Enqueues ETEngine callbacks after SavedScenarioUsers are created/updated/destroyed.
# Delegates to SavedScenarioUsers::PerformEngineCallbacks for the actual work.
class SavedScenarioUserCallbacksJob < ApplicationJob
  queue_as :default

  def perform(saved_scenario_id, user_id, version_tag, operations)
    user = User.find(user_id)
    saved_scenario = SavedScenario.find(saved_scenario_id)
    version = Version.find_by(tag: version_tag) || Version.default
    http_client = MyEtm::Auth.engine_client(user, version)

    SavedScenarioUsers::PerformEngineCallbacks.call(
      http_client,
      saved_scenario,
      operations: operations
    )
  end
end
