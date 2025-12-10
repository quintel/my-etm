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
  FILTER_PARAMS = [ :search, :version, :featured, area_codes: [], end_years: [] ].freeze

  # Area codes to be treated the same for Filterable
  AREA_DUPS = %w[nl nl2019 nl2023].freeze

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

  scope :by_title,  ->(title) { where("title LIKE ?", "%#{title}%") }
  scope :by_user,   ->(user) { joins(:users).where("name LIKE ?", "%#{user}%") }
  scope :by_search, ->(search) {
    user_scenario_ids = SavedScenarioUser.select(:saved_scenario_id)
      .joins(:user)
      .where("users.name LIKE ?", "%#{search}%")

    where("saved_scenarios.title LIKE ?", "%#{search}%")
      .or(where(id: user_scenario_ids))
  }
  scope :featured,  -> {
    where(id: FeaturedScenario.select(:saved_scenario_id))
  }

  # Returns all saved scenarios whose areas are avaliable.
  def self.available
    kept
  end

  # Public: Used to filter scenarios.
  #
  # Returns a collection of filtered SavedScenarios
  def self.filter(filters)
    scenarios = order(created_at: :desc)

    raw_codes = filters["area_codes"] || []
    area_codes = raw_codes.flat_map { |area| AREA_DUPS.include?(area) ? AREA_DUPS : [ area ] }.uniq

    scenarios = scenarios.featured if filters["featured"].present?
    scenarios = scenarios.where(version: filters["version"]) if filters["version"].present?
    scenarios = scenarios.where(end_year: filters["end_years"]) if filters["end_years"].present?
    scenarios = scenarios.where(area_code: area_codes) if area_codes.present?
    scenarios = scenarios.by_search(filters["search"]) if filters["search"].present?

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
    json = super(except: [ "version_id", "tmp_description" ])
    json.merge(
      "version" => version.tag,
      "title" => localized_title(:en),
      "description" => description.to_plain_text.presence,
      "saved_scenario_users" => saved_scenario_users.map { |u| u.as_json(only: %i[user_id role]) }
    )
  end

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

  # Allow version to be set by either tag or Version object
  def version=(version_or_tag)
    if version_or_tag.is_a?(Version)
      self.version_id = version_or_tag.id
    elsif version_found = Version.find_by(tag: version_or_tag)
      self.version_id = version_found.id
    else
      self.version_id = Version.default.id
    end
  end
end
