# frozen_string_literal: true

# Represents a saved collection. Contains one or more scenario
# which will be loaded in the Collection interface.
class Collection < ApplicationRecord
  include Discard::Model

  # Discarded scenarios are deleted automatically after this period.
  AUTO_DELETES_AFTER = 60.days

  # Used by Fiterable Concern
  FILTER_PARAMS = %i[title interpolated plain].freeze

  belongs_to :user
  belongs_to :version

  has_many :scenarios,
    class_name: "CollectionScenario",
    dependent: :delete_all

  has_many :collection_saved_scenarios, dependent: :destroy
  has_many :saved_scenarios, through: :collection_saved_scenarios

  validates_presence_of :user_id
  validates :title, presence: true
  validate :validate_scenarios, :validate_scenario_versions

  scope :by_title, ->(title) { where("title LIKE ?", "%#{title}%") }
  scope :interpolated, ->() { where(interpolation: true) }
  scope :plain, ->() { where(interpolation: false) }

  # Public: Creates a new Collection, setting some attributes to match those of the saved
  # scenario. Used for interpolation
  #
  # scenario - The SavedScenario from which a collection is to be created.
  # attrs    - Optional additional attributes to be set on the Collection.
  #
  # Returns an unsaved Collection.
  def self.new_from_saved_scenario(scenario, attrs)
    new({
      area_code: scenario.area_code,
      end_year: scenario.end_year,
      title: scenario.title,
      interpolation: true,
      version: scenario.version,
      saved_scenario_ids: [ scenario.id ]
    }.merge(attrs))
  end

  # Public: Used to filter collections.
  #
  # Returns a collection of filtered Collections
  def self.filter(filters)
    coll = order(created_at: :desc)

    coll = coll.by_title(filters["title"]) if filters["title"].present?

    inter = filters["interpolated"] == "1"
    plain = filters["plain"] == "1"

    if inter || plain
      interpolation_values = []
      interpolation_values << true if inter
      interpolation_values << false if plain
      coll = coll.where(interpolation: interpolation_values)
    end

    coll
  end


  # Public: Destroys all collections which were discarded some time ago.
  def self.destroy_old_discarded!
    discarded
      .where(discarded_at: ..Collection::AUTO_DELETES_AFTER.ago)
      .destroy_all
  end

  def interpolated?
    interpolation
  end

  # Public: returns the direct scenario_id's and the active scenario_id's of any
  # linked saved scenarios
  def latest_scenario_ids
    scenarios.pluck(:scenario_id) + saved_scenarios.pluck(:scenario_id)
  end

  # Public: Returns an way for the MYC app to identify this instance, to use
  # used when directing to the application.
  #
  # For example:
  #
  #   redirect_to(collection_url(myc.redirect_slug))
  #
  # Returns an array.
  def redirect_slug
    latest_scenario_ids.join(",")
  end

  # Public: MYC doesn't have an update at, but we need it for sorting the items
  # in the trash
  def updated_at
    created_at
  end

  def as_json(options = {})
    options[:except] ||= %i[area_code end_year user_id]

    super(options).merge(
      "discarded" => discarded_at.present?,
      "owner" => user.as_json(only: %i[id name]),
      "scenario_ids" => latest_scenario_ids.sort
    )
  end

  def validate_scenarios
    if scenarios.size + saved_scenarios.size > 6
      errors.add(:scenarios, "exceeds maximum of 6 scenarios")
    end
  end

  def validate_scenario_versions
    # Ensure all scenarios match the collection's version
    invalid_scenarios = saved_scenarios.reject { |saved_scenario|
 saved_scenario.version == version }
    if invalid_scenarios.any?
      errors.add(:scenarios, "must all belong to the collection's version (#{version})")
    end
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
