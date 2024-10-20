module SavedScenariosHelper
  # Public: Parses a scenario or preset description with Markdown, removing any
  # unsafe links.
  #
  # Returns an HTML safe string.
  def formatted_scenario_description(description, allow_external_links: false)
    # First check if the description has a div matching the current locale,
    # indicating that a localized version is available.
    localized = Loofah.fragment(description).css(".#{I18n.locale}")

    rendered = RDiscount.new(
      localized.inner_html.presence || description || '',
      :no_image, :smart
    ).to_html

    sanitized = Rails::Html::SafeListSanitizer.new.sanitize(rendered)

    if allow_external_links
      add_rel_to_external_links(sanitized).html_safe
    else
      strip_external_links(sanitized).html_safe
    end
  end

  # Public: Parses the text as HTML, replacing any links to external sites with
  # only their inner text.
  #
  # Returns a string.
  def strip_external_links(text)
    link_stripper = Loofah.fragment(text)

    link_stripper.scrub!(Loofah::Scrubber.new do |node|
      next unless node.name == 'a'

      begin
        uri = URI(node['href'].to_s.strip)
      rescue URI::InvalidURIError
        node.replace(node.inner_text)
        next
      end

      next if uri.relative?

      domain = ActionDispatch::Http::URL.extract_domain(
        uri.host.to_s, ActionDispatch::Http::URL.tld_length
      )

      if !uri.scheme.start_with?('http') && domain != request.domain
        # Disallow any non-HTTP scheme.
        node.replace(node.inner_text)
        next
      end

      node.replace(node.inner_text) unless domain == request.domain
    end)

    link_stripper.inner_html
  end

  # Public: Adds a rel="noopener nofollow" attribute to any external links.
  #
  # Returns a string.
  def add_rel_to_external_links(text)
    link_stripper = Loofah.fragment(text)

    link_stripper.scrub!(Loofah::Scrubber.new do |node|
      next unless node.name == 'a'

      begin
        uri = URI(node['href'].to_s.strip)
        next if uri.relative?
      rescue URI::InvalidURIError
        # Remove the link with the text.
        node.replace(node.inner_text)
        next
      end

      domain = ActionDispatch::Http::URL.extract_domain(
        uri.host.to_s, ActionDispatch::Http::URL.tld_length
      )

      if !uri.scheme.start_with?('http') && domain != request.domain
        # Disallow any non-HTTP scheme.
        node.replace(node.inner_text)
        next
      end

      node[:rel] = 'noopener nofollow' unless domain == request.domain
    end)

    link_stripper.inner_html
  end

  # Public: Given a string, converts CO2 to have a subscript 2.
  #
  # Returns an HTML-safe string.
  def format_subscripts(string)
    h(string).gsub(/\bCO2\b/, 'CO<sub>2</sub>').html_safe if string.present?
  end
end
