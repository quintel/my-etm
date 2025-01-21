class PassthruController < ApplicationController
  def last
    last_page = cookies[:etm_last_visited_page]

    if last_page && valid_redirect_url?(last_page)
      redirect_to last_page, allow_other_host: true
    else
      redirect_to root_path
    end
  end

  private

  def valid_redirect_url?(url)
    uri = URI.parse(url)
    uri.host.blank? || trusted_hosts.include?(uri.host)
  rescue URI::InvalidURIError
    false
  end

  def trusted_hosts
    @trusted_hosts ||= Version.all.flat_map do |version|
      [
        URI.parse(version.model_url).host,
        URI.parse(version.engine_url).host,
        URI.parse(version.collections_url).host
      ]
    end.compact.uniq
  end
end
