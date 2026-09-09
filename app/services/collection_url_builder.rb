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
    if collection.version.tag == "2025.01"
      collections_app_url_backwards_compatible(collection)
    else
      "#{collection.version.collections_url}/collections/#{collection.id}?locale=#{I18n.locale}"
    end
  end

  # Internal: One old version (2025-S1) uses straight session ids and a title param in the url
  # instead of a collection ID
  def collections_app_url_backwards_compatible(collection)
    base = collection.version.collections_url
    slug = collection.redirect_slug
    query = "locale=#{I18n.locale}&title=#{ERB::Util.url_encode(collection.title)}"

    "#{base}/#{slug}?#{query}"
  end
  private_class_method :collections_app_url_backwards_compatible
end
