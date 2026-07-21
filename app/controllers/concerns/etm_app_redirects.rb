# frozen_string_literal: true

# Validates redirect targets that point at another ETM application.
#
# MyETM owns sign-in for the whole ecosystem, so the other apps send users here with the page they were
# trying to reach: ETModel and Collections redirect to /identity/sign_in?return_to=<url>, and after
# signing in the user must land back there rather than on MyETM's own home page.

module EtmAppRedirects
  extend ActiveSupport::Concern

  private

  # Returns the URL if it points at a known ETM app, otherwise nil.
  def validated_etm_url(raw)
    return nil if raw.blank?

    origin = origin_of(raw)
    origin && etm_app_origins.include?(origin) ? raw : nil
  end

  # Scheme, host and non-default port — the part that decides who receives the request.
  def origin_of(raw)
    uri = URI.parse(raw.to_s)
    return nil unless uri.absolute? && %w[http https].include?(uri.scheme) && uri.host.present?

    port = ":#{uri.port}" unless uri.port == uri.default_port
    "#{uri.scheme}://#{uri.host}#{port}"
  rescue URI::InvalidURIError
    nil
  end

  def etm_app_origins
    @etm_app_origins ||=
      (OAuthApplication.pluck(:uri) + [ Settings.auth.issuer ]).filter_map { |uri| origin_of(uri) }.uniq
  end
end
