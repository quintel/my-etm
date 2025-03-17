class PassthruController < ApplicationController
  def last
    last_page = cookies[:etm_last_visited_page]

    if last_page && valid_subdomain_redirect?(last_page)
      redirect_to last_page
    else
      redirect_to root_path
    end
  end

  private

  def valid_subdomain_redirect?(url)
    uri = URI.parse(url)

    return false unless uri.scheme&.match?(/\Ahttps?\z/)

    return true if Rails.env.development? && uri.host == "localhost"

    return false unless uri.host&.end_with?("energytransitionmodel.com")

    true
  rescue URI::InvalidURIError
    false
  end

  def trusted_hosts
    @trusted_hosts ||= Version.all.flat_map do |version|
      [
        URI.parse(version.model_url).host,
        URI.parse(version.engine_url).host,
        URI.parse(version.collections_url).host,
        "myc.energytransitionmodel.com"             # TODO: remove this once we have a proper redirect
      ]
    end.compact.uniq
  end
end
