# frozen_string_literal: true

# Syncs user coupling to ETEngine when a user registers and gets coupled to email-based SavedScenarioUsers.
# This ensures that ScenarioUsers in ETEngine are updated to point to the registered user.
class CoupleUsersToEngineJob < ApplicationJob
  queue_as :default

  # Retry with exponential backoff
  sidekiq_retry_in do |count|
    [ 30, 120, 600 ][count]
  end

  sidekiq_options retry: 3

  retry_on Faraday::Error, wait: :exponentially_longer, attempts: 3

  def perform(user_id, user_email, saved_scenario_ids)
    user = User.find(user_id)

    saved_scenario_ids.each do |saved_scenario_id|
      sync_to_scenario(user, user_email, saved_scenario_id)
    end
  end

  private

  def sync_to_scenario(user, user_email, saved_scenario_id)
    saved_scenario = SavedScenario.find_by(id: saved_scenario_id)
    return unless saved_scenario

    # Get version for API client
    version = saved_scenario.version || Version.default
    http_client = MyEtm::Auth.engine_client(user, version)

    # Sync to current scenario
    couple_to_engine_scenario(http_client, saved_scenario.scenario_id, user.id, user_email)

    # Sync to historical scenarios
    (saved_scenario.scenario_id_history || []).each do |scenario_id|
      couple_to_engine_scenario(http_client, scenario_id, user.id, user_email)
    end
  rescue StandardError => e
    Rails.logger.error("Failed to couple user #{user_id} to SavedScenario #{saved_scenario_id}: #{e.message}")
    Sentry.capture_exception(e)
    raise # Trigger retry
  end

  def couple_to_engine_scenario(http_client, scenario_id, user_id, user_email)
    # Making an authenticated request to ETEngine triggers User.from_jwt! which:
    # 1. Creates the User in ETEngine (if needed)
    # 2. Triggers User.after_create :couple_scenario_users callback
    # 3. The callback automatically couples all ScenarioUsers with this email
    http_client.get("/api/v3/scenarios/#{scenario_id}")
  rescue Faraday::ResourceNotFound
    # Scenario doesn't exist (might have been deleted), skip
    Rails.logger.warn("Scenario #{scenario_id} not found when coupling user")
  rescue Faraday::Error => e
    # Re-raise network errors to trigger retry
    raise
  end
end
