# frozen_string_literal: true

module CollectionUrlBuilder
  module_function

  # Retrieve the full URL to the Collections application for a Collection instance.
  #
  # The URL carries only the collection id: the Collections app resolves it against the API to get
  # the title and the scenario ids.
  #
  # collection - a `Collection` instance.
  #
  # Returns a string.
  def collections_app_url(collection)
    "#{collection.version.collections_url}/collections/#{collection.id}?locale=#{I18n.locale}"
  end
end
