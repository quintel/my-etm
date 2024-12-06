# frozen_string_literal: true

# Given a saved scenarios version tags, parses the version tags of the underlying
# scenarios and presents it as a json to be picked up by the front end
class SavedScenarioHistoryPresenter
  def self.present(saved_scenario, history)
    new(saved_scenario, history).ordered
  end

  def initialize(saved_scenario, history)
    @history = history
    @scenario_ids_ordered = saved_scenario.all_scenario_ids
  end

  # Sorts the version tags in the history based on the ordering within the saved scenarios history
  # With the current scenario being the first, and the oldest scenario last
  def ordered
    @scenario_ids_ordered.filter_map { |id| present(id) }
  end

  private

  def present(scenario_id)
    version = @history[scenario_id.to_s]

    return if version.blank?

    if version.key?('user_id')
      version['frozen'] = false
      version['user_name'] = User.find(version.delete('user_id').to_i).name
    else
      version['frozen'] = true
      version['user_name'] = I18n.t('saved_scenario_users.unknown')
    end

    version['scenario_id'] = scenario_id
    version['description'] ||= ""
    version['updated_at'] = version.delete('last_updated_at')

    SavedScenarioHistory.from_params(version)
  end
end
