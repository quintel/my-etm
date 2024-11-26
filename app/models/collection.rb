# frozen_string_literal: true

# Represents a saved multi-year charts session. Contains one or more scenario
# which will be loaded in the MYC interface.
class Collection < ApplicationRecord # TODO: Check through, this model has not been thoroughly checked after lifting from ETModel
  include Discard::Model

  # Discarded scenarios are deleted automatically after this period.
  AUTO_DELETES_AFTER = 60.days

  belongs_to :user

  has_many :scenarios,
    class_name: 'CollectionScenario',
    dependent: :delete_all

  has_many :multi_year_chart_saved_scenarios, dependent: :destroy
  has_many :saved_scenarios, through: :multi_year_chart_saved_scenarios

  validates_presence_of :user_id
  validates :title, presence: true
  validate :validate_scenarios

  # Public: Creates a new Collection, setting some attributes to match those of the saved
  # scenario.
  #
  # scenario - The SavedScenario from which a collection is to be created.
  # attrs    - Optional additional attributes to be set on the Collection.
  #
  # Returns an unsaved Collection.
  def self.new_from_saved_scenario(scenario, attrs)
    new({
      area_code: scenario.area_code,
      end_year: scenario.end_year,
      title: scenario.title
    }.merge(attrs))
  end

  # Public: Destroys all multi year charts which were discarded some time ago.
  def self.destroy_old_discarded!
    discarded
      .where(discarded_at: ..MultiYearChart::AUTO_DELETES_AFTER.ago)
      .destroy_all
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
  #   redirect_to(myc_url(myc.redirect_slug))
  #
  # Returns an array.
  def redirect_slug
    latest_scenario_ids.join(',')
  end

  # Public: MYC doesn't have an update at, but we need it for sorting the items
  # in the trash
  def updated_at
    created_at
  end

  def as_json(options = {})
    options[:except] ||= %i[area_code end_year user_id]

    super(options).merge(
      'discarded' => discarded_at.present?,
      'owner' => user.as_json(only: %i[id name]),
      'scenario_ids' => latest_scenario_ids.sort
    )
  end

  def validate_scenarios
    if scenarios.size + saved_scenarios.size > 6
      errors.add(:scenarios, 'exceeds maximum of 6 scenarios')
    end
  end
end
