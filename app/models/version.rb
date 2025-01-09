# frozen_string_literal: true

# TODO: port to db and hook into OAuth apps. This is a mess and not nice to keep up for beta and pro!
# A valid version of the ETM
class Version
  URL = "energytransitionmodel.com".freeze
  DEFAULT_TAG =  "latest"

  # Tag => prefix
  LIST = {
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

    if Rails.env.development?
      LOCAL_URLS[context]
    else
      "https://#{LIST[tag]}#{context == 'model' ? '' : "#{context}."}#{URL}"
    end
  end
end
