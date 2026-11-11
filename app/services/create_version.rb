# frozen_string_literal: true

# Creates a stable model version and the OAuth applications its ETModel and ETEngine sign in with.
#
# The tag is the version's year, and its URLs follow from it ("2027" -> https://2027.energytransitionmodel.com).
# Doorkeeper generates each application's client ID and secret; the version's apps are configured
# with them (IDENTITY_CLIENT_ID and IDENTITY_CLIENT_SECRET). Collections signs in through the shared
# session cookie and needs no application.
module CreateVersion
  extend Dry::Monads[:result]

  TAG_FORMAT = /\A\d{4}\z/

  SCOPES = "openid profile email roles scenarios:read scenarios:write scenarios:delete"

  APPLICATIONS = { "etmodel" => :model_url, "engine" => :engine_url }.freeze

  def self.call(tag:, released_on:, hidden: true, owner: User.robot)
    version = Version.new(tag: tag.to_s.strip, released_on:, hidden:)

    unless version.tag.match?(TAG_FORMAT)
      version.errors.add(:tag, :invalid, message: "must be a year, like 2027")
      return Failure(version)
    end

    version.url_prefix = "#{version.tag}."

    ActiveRecord::Base.transaction do
      raise ActiveRecord::Rollback unless version.save

      APPLICATIONS.each do |app, url_method|
        uri = version.public_send(url_method)

        version.oauth_applications.create!(
          name: "#{app}.#{version.tag}",
          uri: uri,
          redirect_uri: "#{uri}/auth/identity/callback",
          scopes: SCOPES,
          confidential: true,
          first_party: true,
          owner: owner
        )
      end
    end

    version.persisted? ? Success(version) : Failure(version)
  end
end
