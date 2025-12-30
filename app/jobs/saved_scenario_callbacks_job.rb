# frozen_string_literal: true

# Enqueues ETEngine callbacks after a SavedScenario is created/updated.
# Delegates to SavedScenario::PerformEngineCallbacks for the actual work.
class SavedScenarioCallbacksJob < ApplicationJob
  queue_as :default

  def perform(scenario_id, user_id, version_tag,
    operations = [ :protect, :set_roles, :tag_version ], saved_scenario_id: nil)
    user = User.find(user_id)
    version = Version.find_by(tag: version_tag) || Version.default
    http_client = MyEtm::Auth.engine_client(user, version)

    SavedScenario::PerformEngineCallbacks.call(
      http_client,
      scenario_id,
      operations: operations.map(&:to_sym),
      saved_scenario_id: saved_scenario_id
    )
  end
end
