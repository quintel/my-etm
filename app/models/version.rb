class Version < ApplicationRecord
  has_many :oauth_applications, dependent: :nullify
  has_many :saved_scenarios
  has_many :collections

  validates :tag, presence: true, uniqueness: true
  validates :url_prefix, presence: true, unless: -> { tag == "latest" }
  validate  :one_default

  URL = "energytransitionmodel.com".freeze
  LOCAL_URLS = {
    "collections" => Settings.collections.uri,
    "model"       => Settings.etmodel.uri,
    "engine"      => Settings.etengine.uri
  }.freeze

  # Fetch all version tags
  def self.tags
    pluck(:tag).reject { |tag| tag == "local" && !Rails.env.development? }
  end

  # Find or create the default version
  def self.default
    find_by(default: true) || create(default: true, tag: "latest")
  end

  # Find or create the local version
  def self.local
    if Rails.env.development?
      find_by(tag: "local") || create!(tag: "local", url_prefix: "local")
    else
      Version.default
    end
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

  def titleize
    tag.titleize
  end

  # Serialize versions for API responses
  def as_json(*)
    {
      tag: tag,
      model_url: model_url,
      engine_url: engine_url,
      collections_url: collections_url
    }
  end

  def urls
    [ model_url, engine_url, collections_url ]
  end

  private

  # Build the URL for the given contextand tag, using "-" for collections.
  def build_url(context)
    return LOCAL_URLS[context] if Rails.env.development?

    case context
    when "collections"
      "https://#{url_prefix.to_s.sub('.', '-')}collections.#{URL}"
    else
      # Convert nil to empty string and ensure proper dot formatting
      prefix = url_prefix.to_s.presence ? url_prefix : ""
      "https://#{prefix}#{context == 'model' ? '' : "#{context}."}#{URL}"
    end
  end

  def one_default
    if default && Version.where(default: true).count.positive?
      errors.add(:base, :default, message: "There can only be one default version")
    end
  end
end
