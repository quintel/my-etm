# frozen_string_literal: true

# A scenario saved by a user for safe-keeping.
#
# Contains a record of all the scenario IDs for previous versions of the
# scenario.
class SavedScenario < ApplicationRecord
  include Discard::Model
  include SavedScenario::History
  include SavedScenario::Featured
  include SavedScenario::Users

  # Discarded scenarios are deleted automatically after this period.
  AUTO_DELETES_AFTER = 60.days

  has_one :featured_scenario, dependent: :destroy
  has_many :saved_scenario_users, dependent: :destroy
  has_many :users, through: :saved_scenario_users
  # has_many :users, through: :saved_scenario_users
  has_rich_text :description

  validates :scenario_id, presence: true
  validates :title,       presence: true
  validates :end_year,    presence: true
  validates :area_code,   presence: true
  validates :version, presence: true, inclusion: {
    in: Version.all, message: "Version should be one of #{Version.all}"
  }

  serialize :scenario_id_history, coder: YAML, type: Array

  # Returns all saved scenarios whose areas are avaliable.
  def self.available
    kept.where(area_code: Engine::Area.keys)
  end

  def scenario(engine_client)
    unless engine_client.is_a?(Faraday::Connection)
      raise "SavedScenario#scenario expects an HTTP client as its first argument"
    end

    @scenario ||= FetchAPIScenario.call(engine_client, scenario_id).or(nil)
  end

  # Public: Determines if this scenario can be loaded.
  def loadable?
    Engine::Area.code_exists?(area_code)
  end

  def days_until_last_update
    (Time.current - updated_at) / 60 / 60 / 24
  end
end
