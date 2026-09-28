# frozen_string_literal: true

# Tells Collections that a saved scenario changed
class InvalidateCollectionScenarioJob < ApplicationJob
  AUDIENCE = "collections-events"

  queue_as :default

  # Collections re-resolves every five minutes, so a lost event only costs latency
  retry_on Faraday::ConnectionFailed, Faraday::TimeoutError, Faraday::ServerError, attempts: 3 do |job, error|
    log_failure(job, error)
  end

  # A 4xx will not improve on retry: a frozen version's Collections has no receiver, or it refused the event
  discard_on Faraday::ClientError do |job, error|
    log_failure(job, error)
  end

  discard_on ActiveJob::DeserializationError

  def self.log_failure(job, error)
    Rails.logger.warn("Collections event failed for saved scenario #{job.arguments.first&.id}: #{error.message}")
  end

  def perform(saved_scenario)
    client(saved_scenario.version).post(
      "/api/invalidate/scenarios/#{saved_scenario.id}", nil,
      "Authorization" => "Bearer #{event_for(saved_scenario)}"
    )
  end

  private

  def event_for(saved_scenario)
    MyEtm::Auth.sign_event(
      { saved_scenario_id: saved_scenario.id, stamp: saved_scenario.updated_at.utc.iso8601(6) },
      audience: AUDIENCE
    )
  end

  def client(version)
    Faraday.new(url: version.collections_url, request: { timeout: 5 }) do |conn|
      conn.response(:raise_error)
    end
  end
end
