# frozen_string_literal: true

# Creates an ETEngine Session with input values interpolated from another Session, for an earlier
# end year.
#
# http_client     - A client for the Version's ETEngine, granted to clone the source Session.
# scenario_id     - The ID of the source Session.
# end_year        - The end year of the new Session.
# keep_compatible - Flag the new Session to be migrated when the model changes.
#
# Returns a Dry::Monads::Result with the new Session's JSON. A refusal carries ETEngine's errors
# under end_year, as they are all about the year, and any other failure an [:upstream, messages] pair.
class ApiScenario::Interpolate
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :http_client
  param :scenario_id
  param :end_year
  option :keep_compatible, default: proc { false }

  def call
    Success(http_client.post("/api/v3/scenarios/#{scenario_id}/interpolate", end_year:, keep_compatible:).body)
  rescue Faraday::UnprocessableEntityError => e
    Failure(end_year: Array(e.response[:body]["errors"]))
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    Failure([ :upstream, [ "Failed to interpolate scenario" ] ])
  end
end
