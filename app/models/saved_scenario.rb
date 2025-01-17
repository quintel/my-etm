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

  # Used by Fiterable Concern
  FILTER_PARAMS = %i[title].freeze

  has_one :featured_scenario, dependent: :destroy
  has_many :saved_scenario_users, dependent: :destroy
  has_many :users, through: :saved_scenario_users
  belongs_to :version

  has_rich_text :description

  validates :scenario_id, presence: true, numericality: { only_integer: true }
  validates :title,       presence: true
  validates :end_year,    presence: true
  validates :area_code,   presence: true

  serialize :scenario_id_history, coder: YAML, type: Array

  scope :by_title, ->(title) { where("title LIKE ?", "%#{title}%") }

  # Returns all saved scenarios whose areas are avaliable.
  def self.available
    # kept.where(area_code: Engine::Area.keys)
    kept
  end

  # Public: Used to filter scenarios.
  #
  # Returns a collection of filtered SavedScenarios
  def self.filter(filters)
    scenarios = order(created_at: :desc)

    scenarios = scenarios.by_title(filters["title"]) if filters["title"].present?

    scenarios
  end

  # Public: Destroys all scenarios which were discarded some time ago.
  def self.destroy_old_discarded!
    discarded
      .where(discarded_at: ..SavedScenario::AUTO_DELETES_AFTER.ago)
      .destroy_all
  end

  def restore_version(scenario_id)
    return unless scenario_id && scenario_id_history.include?(scenario_id)

    discard_no = scenario_id_history.index(scenario_id)
    discarded = scenario_id_history[discard_no + 1...]

    self.scenario_id = scenario_id
    self.scenario_id_history = scenario_id_history[...discard_no]

    discarded
  end

  def scenario=(x)
    @scenario = x
    self.scenario_id = x.id unless x.nil?
  end

  def as_json(*)
    json = super.except(:version_id)
    json.merge("version" => version.tag)
  end

  # TODO: Determine if necessary
  # # Public: Determines if this scenario can be loaded.
  # def loadable?
  #   Engine::Area.code_exists?(area_code)
  # end

  def days_until_last_update
    (Time.current - updated_at) / 60 / 60 / 24
  end

  def self.owned_by?(user)
    joins(:saved_scenario_users)
      .where(
        'saved_scenario_users.user_id': user.id,
        'saved_scenario_users.role_id': User::Roles.index_of(:scenario_owner)
      )
  end

  def self.collaborated_by?(user)
    joins(:saved_scenario_users)
      .where(
        'saved_scenario_users.user_id': user.id,
        'saved_scenario_users.role_id': User::Roles.index_of(:scenario_collaborator)..
      )
  end

  def self.viewable_by?(user)
    joins(:saved_scenario_users)
      .where(
        'saved_scenario_users.user_id': user.id,
        'saved_scenario_users.role_id': User::Roles.index_of(:scenario_viewer)..
      )
  end

  def self.batch_load(saved_scenarios, options = {})
    saved_scenarios = saved_scenarios.to_a
    ids = saved_scenarios.map(&:scenario_id)
    loaded = Engine::Scenario.batch_load(ids, options).index_by(&:id)

    saved_scenarios.each do |saved|
      saved.scenario = loaded[saved.scenario_id]
    end

    saved_scenarios
  end
end
