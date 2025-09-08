# frozen_string_literal: true

module SavedScenarioHelper
  # Returns true if there is a special warning for the scenario
  #
  # Current use: dataset 2023 update for Dutch regions. Show banner
  # when scenario on latest with elegible dataset
  def warning_for(saved_scenario)
    return false unless saved_scenario.version.default

    %w[GM RES PV].any? { |code| saved_scenario.area_code.start_with?(code) }
  end
end
