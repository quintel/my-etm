# frozen_string_literal: true

module CollectionUrlBuilder
  module_function

  # Retrieve the full URL to the Collections application for a Collection instance.
  #
  # collection - a `Collection` instance.
  #
  # Returns a string.
  def collections_app_url(collection)
    base = collection.version.collections_url
    slug = collection.redirect_slug
    query = "locale=#{I18n.locale}&title=#{ERB::Util.url_encode(collection.title)}"

    "#{base}/#{slug}?#{query}"
  end
end
