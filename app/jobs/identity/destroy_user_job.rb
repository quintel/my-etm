# frozen_string_literal: true

# Permanently deletes a user.
class Identity::DestroyUserJob < ApplicationJob
  queue_as :default

  retry_on Faraday::Error, wait: :polynomially_longer, attempts: 3

  def perform(user_id)
    user = User.find_by(id: user_id)
    return true if user.nil?

    Version.all.each { |version| purge_remotely(user, version) }

    user.destroy

    true
  end

  private

  # A retry re-sends deletes that already succeeded, so an absent remote user counts as done
  def purge_remotely(user, version)
    MyEtm::Auth.model_client(user, version).delete("/api/v1/user") if Settings.etmodel.uri
    MyEtm::Auth.engine_client(user, version).delete("/api/v3/user") if Settings.etengine.uri
  rescue Faraday::ResourceNotFound
    nil
  rescue StandardError => e
    Sentry.capture_exception(e)
    raise
  end
end
