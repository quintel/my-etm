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

  has_many :collection_saved_scenarios, dependent: :destroy,  autosave: true, inverse_of: :collection
  has_many :saved_scenarios,
    -> { order("collection_saved_scenarios.saved_scenario_order ASC") },
    through: :collection_saved_scenarios

  # Allow nested attributes so child changes are saved/validated with parent
  accepts_nested_attributes_for :collection_saved_scenarios, allow_destroy: true

  validates_presence_of :user_id
  validates :title, presence: true
  validate :validate_scenarios, :validate_scenario_versions, :validate_interpolated

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
    collection = new({
      area_code: scenario.area_code,
      end_year: scenario.end_year,
      title: scenario.title,
      interpolation: true,
      version: scenario.version
    }.merge(attrs))

    collection.collection_saved_scenarios.build(saved_scenario: scenario)

    collection
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

  def as_json(options = {})
    options[:except] ||= %i[area_code end_year user_id]

    super(options).merge(
      "discarded" => discarded_at.present?,
      "owner" => user.as_json(only: %i[id name]),
      "scenario_ids" => latest_scenario_ids
    )
  end

  # Public: Updates the saved scenarios associated with this collection if any,
  # ordering them as passed.
  def saved_scenario_ids=(sorted_ids)
    return true if sorted_ids.nil? || sorted_ids.empty?

    sorted_ids = sorted_ids.map(&:to_i)

    # Mark for removal existing scenario relations that were not passed
    nested_attrs = saved_scenario_ids.filter_map do |ss_id|
      { id: [ self.id, ss_id ], _destroy: true } unless sorted_ids.include?(ss_id)
    end

    # Create new or update existing scenario relations that were passed
    sorted_ids.uniq.each.with_index(1) do |ss_id, ss_order|
      if saved_scenario_ids.include?(ss_id)
        nested_attrs << { id: [ self.id, ss_id ], saved_scenario_order: ss_order }
      else
        nested_attrs << { saved_scenario_id: ss_id, saved_scenario_order: ss_order }
      end
    end

    # Make changes in-memory only. Will not persist until collection is saved
    self.collection_saved_scenarios_attributes = nested_attrs
  end

  def validate_scenarios
    active_saved_scenarios = collection_saved_scenarios.reject(&:marked_for_destruction?)
    if scenarios.size + active_saved_scenarios.size > 6
      errors.add(:scenarios, "exceeds maximum of 6 scenarios")
    end
  end

  def validate_scenario_versions
    # Ensure all scenarios match the collection's version
    invalid_scenarios = saved_scenarios.reject do |saved_scenario|
      saved_scenario.version == version
    end
    if invalid_scenarios.any?
      errors.add(:scenarios, "must all belong to the collection's version (#{version})")
    end
  end

  def validate_interpolated
    # Ensure interpolated collections (AKA transition paths) have no saved scenarios
    active_saved_scenarios = collection_saved_scenarios.reject(&:marked_for_destruction?)
    if self.interpolated? && active_saved_scenarios.size > 1
      errors.add(:scenarios, "interpolated collections cannot have more than 1 saved scenario")
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
