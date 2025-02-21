module ApplicationHelper
  def notice_message
    if notice.is_a?(Hash)
      notice[:message] || notice["message"]
    else
      notice
    end
  end

  def alert_message
    if alert.is_a?(Hash)
      alert[:message] || alert["message"]
    else
      alert
    end
  end

  def identity_back_to_etm_url
    session[:back_to_etm_url] || Settings.etmodel_uri || "https://energytransitionmodel.com"
  end

  # Like simple_format, except without inserting breaks on newlines.
  def format_paragraphs(text)
    # rubocop:disable Rails/OutputSafety
    text.split("\n\n").map { |content| content_tag(:p, sanitize(content)) }.join.html_safe
    # rubocop:enable Rails/OutputSafety
  end

  def format_staff_config(config, app)
    etengine_url = Settings.etengine.uri || "http://YOUR_ETENGINE_URL"

    format(config, app.attributes.symbolize_keys.merge(
      myetm_url: root_url.chomp("/"),
      etengine_url: etengine_url,
      etmodel_url: Settings.etmodel.uri || "http://YOUR_ETMODEL_URL",
      collections_url: Settings.collections.uri || "http://YOUR_COLLECTIONS_URL",
      nextauth_secret: SecureRandom.hex(32)
    ))
  end

  def format_staff_run_command(command, app)
    format(command, port: app.uri ? URI.parse(app.uri).port : nil)
  end
end
