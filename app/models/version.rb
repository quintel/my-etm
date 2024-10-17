# frozen_string_literal: true

# A valid version of the ETM
class Version
  LIST = %i[
    latest
  ].freeze

  # All available versions. Uses ActiveRecord syntax 'all' to
  # make future porting to db easier
  def self.all
    LIST
  end
end
