class Version < ApplicationRecord
  URL = "energytransitionmodel.com".freeze
  LOCAL_URLS = {
    "collections" => Settings.collections_url,
    "model" => Settings.etmodel.uri,
    "engine" => Settings.etengine.uri
  }.freeze

  validates :tag, presence: true, uniqueness: true
  validates :url_prefix, presence: true, unless: -> { tag == "latest" }

  # Fetch all version tags
  def self.tags
    pluck(:tag)
  end

  # Find the default version
  def self.default
    find_by(default: true)
  end

  # URL methods for collections, model, and engine
  def collections_url
    build_url("collections")
  end

  def model_url
    build_url("model")
  end

  def engine_url
    build_url("engine")
  end

  # Serialize versions for API responses
  def as_json(*)
    super.merge(
      model_url: model_url,
      engine_url: engine_url,
      collections_url: collections_url
    )
  end

  private

  # Build the URL for the given context and tag
  def build_url(context)
    if Rails.env.development?
      LOCAL_URLS[context]
    else
      "https://#{url_prefix}#{context == 'model' ? '' : "#{context}."}#{URL}"
    end
  end
end
