# frozen_string_literal: true

# Sets or clears ETEngine's `bound` flag, which marks a Session as held by an undiscarded saved
# scenario, as its current Session or a snapshot. Clearing it also stops keeping the Session
# compatible, so ETEngine may clean it up.
#
# user    - The user acting, who owns the engine token.
# version - The Version whose ETEngine holds the Sessions.
# ids     - The IDs of the Sessions to bind or unbind.
# bound   - True to bind the Sessions, false to unbind them.
#
# Returns a Dry::Monads::Result whose value lists the IDs ETEngine has no Session for. A failure
# carries an [:upstream, messages] pair. call! returns the IDs directly and raises a Faraday::Error
# instead, for callers that report each failure themselves.
class ApiScenario::SetBound
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  SCOPE = "scenarios:bind"

  param :user
  param :version
  param :ids
  param :bound

  def self.call!(user, version, ids, bound)
    new(user, version, ids, bound).call!
  end

  def self.for_saved_scenario(user, saved_scenario, bound)
    call(user, saved_scenario.version, saved_scenario.all_scenario_ids, bound)
  end

  # Binds Sessions into a saved scenario. ETEngine binds only Sessions the user may update that no
  # saved scenario holds yet
  def self.bind_into(user, saved_scenario, ids)
    result = call(user, saved_scenario.version, ids, true)
    return result unless result.failure? && result.failure.first == :refused

    saved_scenario.errors.add(:scenario_id, :refused, message: "is already saved, or you cannot edit it")
    Dry::Monads::Failure(saved_scenario.errors)
  end

  def self.supported?(version)
    Settings.versions_without_bound_flag.exclude?(version.tag)
  end

  def call
    Success(call!)
  rescue Faraday::UnprocessableEntityError => e
    Failure([ :refused, e.response_body["refused"] ])
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    Failure([ :upstream, [ "Failed to update the session in ETEngine" ] ])
  end

  def call!
    return release_without_bound_flag unless self.class.supported?(version)

    client.put("/api/v3/scenarios/bind", ids:, bound:).body["missing"]
  end

  private

  # TEMPORARY(2025.01): an engine without the bound flag only needs dont_keep_compatible to be called
  def release_without_bound_flag
    return [] if bound

    engine = client
    ids.each { |id| ApiScenario::SetCompatibility.dont_keep_compatible(engine, id) }
    []
  end

  def client
    engine = OAuthApplication.find_by(uri: version.engine_url)
    MyEtm::Auth.client_for(user, engine, scopes: [ engine.scopes.to_s, SCOPE ])
  end
end
