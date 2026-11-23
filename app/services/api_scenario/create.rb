# frozen_string_literal: true

# Creates an ETEngine Session: fresh from an area_code and end_year, or cloned from a scenario_id.
#
# http_client - A client for the Version's ETEngine, granted on any Session it clones.
# attributes  - Either area_code and end_year, or a scenario_id, and optionally private.
#
# Returns a Dry::Monads::Result with the new Session's JSON. A refusal carries ETEngine's errors per
# attribute, and any other failure an [:upstream, messages] pair.
class ApiScenario::Create
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :http_client
  param :attributes

  def call
    Success(http_client.post("/api/v3/scenarios", scenario: attributes).body)
  rescue Faraday::UnprocessableEntityError => e
    Failure(e.response[:body]["errors"])
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    Failure([ :upstream, [ "Failed to create the session in ETEngine" ] ])
  end
end
