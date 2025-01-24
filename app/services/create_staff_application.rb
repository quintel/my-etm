# frozen_string_literal: true

# Creates or updates an OAuth application for a given staff user.
#
# If the user already has an application with the same name, it will be updated and their chosen
# hostname will be preserved in both the URI and redirect URI.
module CreateStaffApplication
  extend Dry::Monads[:result]

  def self.call(user, app_config, uri: nil)
    # Find or initialize the staff application
    staff_app = user.staff_applications.find_or_initialize_by(name: app_config.key)

    # Parse and normalize the URI
    parsed_uri = parse_and_normalize_uri(uri || staff_app.application&.uri || app_config.uri)

    # Check if an application with this URI already exists
    app = Doorkeeper::Application.find_by(uri: parsed_uri.to_s) ||
          staff_app.application ||
          user.oauth_applications.new

    # Build redirect URI
    redirect_uri = parsed_uri.dup
    redirect_uri.path = app_config.redirect_path

    # Update application attributes
    app.attributes = app_config.to_model_attributes.merge(
      owner_id: user.id,
      uri: parsed_uri.to_s,
      redirect_uri: redirect_uri.to_s,
      version_id: Version.default.id
    )

    # Save the application and handle failures
    return Failure(app) unless app.save

    # Update and save the staff application
    staff_app.name = app_config.key
    staff_app.application = app

    staff_app.save ? Success(staff_app) : Failure(staff_app)
  end

  private

  def self.parse_and_normalize_uri(uri_string)
    uri = URI.parse(uri_string)
    uri.path = ""
    uri.query = nil
    uri.fragment = nil
    uri
  rescue URI::InvalidURIError
    raise ArgumentError, "Invalid URI: #{uri_string}"
  end
end
