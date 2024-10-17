# frozen_string_literal: true

# A scenario saved by a user for safe-keeping.
#
# Contains a record of all the scenario IDs for previous versions of the
# scenario.
class SavedScenario < ApplicationRecord
  include Discard::Model

  # Discarded scenarios are deleted automatically after this period.
  AUTO_DELETES_AFTER = 60.days

  validates :scenario_id, presence: true
  validates :title,       presence: true
  validates :end_year,    presence: true
  validates :area_code,   presence: true
  validates :version, presence: true, inclusion: {
    in: Version.all
  }

  serialize :scenario_id_history, coder: YAML, type: Array
end
