# frozen_string_literal: true

# Validates redirect targets that point at another ETM application.
#
# MyETM owns sign-in for the whole ecosystem, so the other apps send users here with the page they
# were trying to reach: ETModel and Collections redirect to /identity/sign_in?return_to=<url>, and
# after signing in the user must land back there rather than on MyETM's own home page.
module EtmAppRedirects
  module_function

  # Returns the URL if it points at a known ETM app, otherwise nil.
  def validate(raw)
    return if raw.blank?

    app_origins.include?(origin_of(raw)) ? raw : nil
  end

  # Scheme, host and non-default port — the part that decides who receives the request.
  def origin_of(raw)
    uri = URI.parse(raw.to_s)
    return unless uri.absolute? && %w[http https].include?(uri.scheme) && uri.host.present?

    port = uri.port == uri.default_port ? "" : ":#{uri.port}"
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  # Deliberately not memoized: applications are registered while the process lives, and a sign-in
  # costs one pluck per check.
  def app_origins
    (OAuthApplication.pluck(:uri) + [ Settings.auth.issuer ])
      .filter_map { |uri| origin_of(uri) }
      .uniq
  end
end
