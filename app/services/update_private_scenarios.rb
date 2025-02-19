# frozen_string_literal: true

# Updates a User's default setting for the privacy of their scenarios.
class UpdatePrivateScenarios
  include Service

  def self.call_with_user(http_client, user, private_scenarios)
    new(http_client, user, private_scenarios).call
  end

  def initialize(http_client, user, private_scenarios)
    @http_client = http_client
    @user = user
    @private_scenarios = ActiveModel::Type::Boolean.new.cast(private_scenarios)
  end

  def call
    response = @http_client.put(
      "/api/v3/user",
      user: { private_scenarios: @private_scenarios }
    )

    if response.success?
      ServiceResult.success
    else
      ServiceResult.failure("Failed to update scenario: #{response.status}")
    end
  rescue Faraday::ResourceNotFound
    ServiceResult.failure("User not found")
  rescue Faraday::UnprocessableEntityError
    ServiceResult.failure("Invalid data provided")
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    ServiceResult.failure("Failed to update scenario due to an error")
  end
end
