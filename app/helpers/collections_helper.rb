# frozen_string_literal: true

module CollectionsHelper
  # Public: The full URL to the Collections application for an instance of
  # Collections.
  #
  # Returns a string.
  def collection_url(collection)
    CollectionUrlBuilder.collections_app_url(collection)
  end

  def can_use_as_myc_scenario?(saved_scenario)
    saved_scenario.end_year == 2050
  end
end
