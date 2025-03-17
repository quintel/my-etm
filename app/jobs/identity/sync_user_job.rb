# frozen_string_literal: true

require "uri"
require "net/http"

# Syncs a user's identity with ETModel.
class Identity::SyncUserJob < ApplicationJob
  queue_as :default

  def perform(user_id)
    return false unless Settings.etmodel.uri && Settings.etengine.uri

    user = User.find(user_id)

    Version.all.each do |version|
      sync_user(user, version, :model)
      sync_user(user, version, :engine)
    end

    true
  end

  private

  def sync_user(user, version, service)
    client = service == :model ? MyEtm::Auth.model_client(user,
      version) : MyEtm::Auth.engine_client(user, version)
    endpoint = service == :model ? "/api/v1/user" : "/api/v3/user"
    payload = user.as_json(except: %i[admin created_at updated_at])
    payload[:id] = user.id if service == :engine

    Rails.logger.info("Syncing #{service.capitalize}: #{endpoint}")

    begin
      response = client.put(endpoint, payload)
      Rails.logger.info("#{service.capitalize} Response: #{response.status} - #{response.body}")
    rescue Faraday::ServerError, Faraday::ClientError, StandardError => e
      handle_request_errors(e, service)
      return false
    end

    true
  end

  def handle_request_errors(error, service)
    log_error_details(error, service)
    log_error_response(error)
    log_error_backtrace(error)
  end

  def log_error_details(error, service)
    Rails.logger.error("#{error.class} (#{service.capitalize}): #{error.message}")
  end

  def log_error_response(error)
    return unless error.respond_to?(:response) && error.response

    begin
      Rails.logger.error("Response: #{error.response.inspect}")
    rescue NoMethodError
      Rails.logger.error(
        "Error object lacks a response attribute: #{error.class} - " \
        "#{error.message}"
      )
    end
  end

  def log_error_backtrace(error)
    return unless error.is_a?(StandardError)

    Rails.logger.error(error.backtrace.join("\n"))
  end
end
