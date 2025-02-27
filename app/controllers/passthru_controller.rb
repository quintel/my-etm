class PassthruController < ApplicationController
  def last
    last_page = cookies[:etm_last_visited_page]

    if last_page && valid_redirect_url?(last_page)
      redirect_to last_page, allow_other_host: true
    else
      redirect_to root_path
    end
  end

  # Back within the application
  def back
    if session[:previous_pages].present? && session[:previous_pages].size > 2
      session[:previous_pages].pop
      redirect_to session[:previous_pages].pop
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
        URI.parse(version.collections_url).host,
        "myc.energytransitionmodel.com"             # TODO: remove this once we have a proper redirect
      ]
    end.compact.uniq
  end
end
