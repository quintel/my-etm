# frozen_string_literal: true

module MyEtm
  # Mailchimp is a module which provides a client for the Mailchimp API.
  module Mailchimp
    module_function

    # Checks if Mailchimp is configured for a given audience
    def enabled?
      Settings.mailchimp.newsletter.list_url.present? &&
      Settings.mailchimp.newsletter.api_key.present? &&
      Settings.mailchimp.changelog.list_url.present? &&
      Settings.mailchimp.changelog.api_key.present?
    end

    # Returns a Mailchimp API client for the given audience
    def client(audience)
      audience = audience.is_a?(Hash) ? audience[:audience]&.to_sym : audience&.to_sym
      raise ArgumentError, "Invalid audience: #{audience.inspect}" unless %i[newsletter changelog].include?(audience)

      Faraday.new(Settings.mailchimp[audience][:list_url]) do |conn|
        conn.request(:authorization, :basic, "", Settings.mailchimp[audience][:api_key])
        conn.request(:json)
        conn.response(:json)
        conn.response(:raise_error)
      end
    end

    # Returns the subscriber ID for a given email
    def subscriber_id(email)
      Digest::MD5.hexdigest(email.downcase)
    end

    # Fetches subscriber information for a given email and audience
    def fetch_subscriber(email, audience)
      client(audience).get("members/#{subscriber_id(email)}").body
    end

    # Checks if an email is subscribed to a given audience
    def subscribed?(email, audience)
      %w[pending subscribed].include?(fetch_subscriber(email, audience)["status"])
    rescue Faraday::ResourceNotFound
      false
    end

    # Subscribes an email to a given audience
    def subscribe(email, audience, merge_fields: {}, status: "subscribed")
      client(audience).put("members/#{subscriber_id(email)}", {
        email_address: email,
        status: status,
        merge_fields: merge_fields
      }).body
    end

    # Unsubscribes an email from a given audience
    def unsubscribe(email, audience)
      client(audience).patch("members/#{subscriber_id(email)}", {
        status: "unsubscribed"
      }).body
    end
  end
end
