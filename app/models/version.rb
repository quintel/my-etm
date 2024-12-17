# frozen_string_literal: true

# A valid version of the ETM
class Version
  URL = "energytransitionmodel.com".freeze

  # Tag => prefix
  LIST = {
    "latest" => "",
    "stable.01" => "stable.",
    "stable.02" => "stable2."
  }.freeze

  # All available versions. Uses ActiveRecord syntax 'all' to
  # make future porting to db easier
  def self.all
    LIST
  end

  def self.tags
    LIST.keys
  end

  def self.model_url(tag)
    "https://#{LIST[tag]}#{Version::URL}"
  end

  def self.engine_url(tag)
    "https://#{LIST[tag]}engine.#{Version::URL}"
  end

  # TODO: Collections url

  # TODO: urls for local development => Add a local version and
  # exceptions for the urls

  def self.as_json(*)
    Version.tags.map do |tag|
      {
        tag: tag,
        url: Version.model_url(tag),
        engine_url: Version.engine_url(tag)
      }
    end
  end
end
