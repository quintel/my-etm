# frozen_string_literal: true

# A valid version of the ETM
class Version
  URL = "energytransitionmodel.com".freeze

  LIST = {
    "latest" => "https://#{Version::URL}",
    "stable.01" => "https://stable.#{Version::URL}",
    "stable.02" => "https://stable2.#{Version::URL}"
  }.freeze

  # All available versions. Uses ActiveRecord syntax 'all' to
  # make future porting to db easier
  def self.all
    LIST
  end

  def self.tags
    LIST.keys
  end

  def self.as_json(*)
    LIST.map { |tag, url| { tag: tag, url: url } }
  end
end
