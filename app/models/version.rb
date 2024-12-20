# frozen_string_literal: true

# A valid version of the ETM
class Version
  URL = "energytransitionmodel.com".freeze
  DEFAULT_TAG = Rails.env.development? ? "local" : "latest" # Default to "local" in development

  # Tag => prefix
  LIST = {
    "local" => "",
    "latest" => "",
    "stable.01" => "stable.",
    "stable.02" => "stable2."
  }.freeze

  LOCAL_URLS = {
    "collections" => Settings.collections.uri,
    "model" => Settings.etmodel.uri,
    "engine" => Settings.etengine.uri
  }.freeze

  # All available versions. Uses ActiveRecord syntax 'all' to
  # make future porting to db easier
  def self.all
    LIST
  end

  def self.tags
    LIST.keys
  end

  def self.collections_url(tag = nil)
    build_url("collections", tag)
  end

  def self.model_url(tag = nil)
    build_url("model", tag)
  end

  def self.engine_url(tag = nil)
    build_url("engine", tag)
  end

  def self.as_json(*)
    Version.tags.map do |tag|
      {
        tag: tag,
        model_url: model_url(tag),
        engine_url: engine_url(tag),
        collections_url: collections_url(tag)
      }
    end
  end

  private

  def self.build_url(context, tag)
    tag ||= DEFAULT_TAG
    raise ArgumentError, "Invalid version tag: #{tag}" unless LIST.key?(tag)

    if tag == "local"
      LOCAL_URLS[context]
    else
      "https://#{LIST[tag]}#{context == 'model' ? '' : "#{context}."}#{URL}"
    end
  end
end
