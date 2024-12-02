# frozen_string_literal: true

# Contains methods concerning scenario ID history
module SavedScenario::History
  # Public: Returns true if the scenario ID is part of the history
  def contains?(scenario_id)
    scenario_id_history.include?(scenario_id)
  end

  # Public: Adds the ID to the history. Max history is 100 scenarios.
  def add_id_to_history(scenario_id)
    return if !scenario_id || contains?(scenario_id)

    scenario_id_history.shift if scenario_id_history.count >= 100
    scenario_id_history << scenario_id
  end

  # Public: Restores the scenario id to the given historical scenario
  # Returns the discarded scenarios from the history
  def restore_historical(scenario_id)
    return unless scenario_id && contains?(scenario_id)

    discard_no = scenario_id_history.index(scenario_id)
    discarded = scenario_id_history[discard_no + 1...]

    self.scenario_id = scenario_id
    self.scenario_id_history = scenario_id_history[...discard_no]

    discarded
  end

  # Returns an array containing the current and historical scenario ids
  def all_scenario_ids
    [ scenario_id ] + scenario_id_history.reverse
  end
end
