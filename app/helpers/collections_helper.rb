# frozen_string_literal: true
module CollectionsHelper
  # Public: The full URL to the Collections application for an instance of
  # Collections.
  #
  # Returns a string.
  def myc_url(collection)
    "#{Settings.collections_url}/#{collection.redirect_slug}?" \
      "locale=#{I18n.locale}&" \
      "title=#{ERB::Util.url_encode(collection.title)}"
  end

  def can_use_as_myc_scenario?(saved_scenario)
    saved_scenario.end_year == 2050
  end
end
