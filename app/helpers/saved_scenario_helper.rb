# frozen_string_literal: true

module SavedScenarioHelper
  # Returns true if there is a special warning for the scenario
  #
  # Current use: dataset 2023 update for Dutch regions. Show banner
  # when scenario on latest with elegible dataset and updated before Oct 2nd
  def warning_for(saved_scenario)
    return false unless saved_scenario.version.default
    return false unless saved_scenario.updated_at < Date.new(2024, 10, 2)

    %w[GM ES PV].any? { |code| saved_scenario.area_code.start_with?(code) } && saved_scenario.area_code != "ES_spain"
  end
end
