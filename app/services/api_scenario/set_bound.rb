# frozen_string_literal: true

# Sets or clears ETEngine's `bound` flag, which marks a Session as held by an undiscarded saved
# scenario, as its current Session or a snapshot. Clearing it also stops keeping the Session
# compatible, so ETEngine may clean it up.
#
# Returns a ServiceResult whose value lists the IDs ETEngine has no Session for
module ApiScenario::SetBound
  module_function

  SCOPE = "scenarios:bind"

  def call(user, version, ids, bound)
    ServiceResult.success(call!(user, version, ids, bound))
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    ServiceResult.failure("Failed to update the session in ETEngine")
  end

  # Raises a Faraday::Error when ETEngine fails
  def call!(user, version, ids, bound)
    return release_without_bound_flag(user, version, ids, bound) unless supported?(version)

    client(user, version).put("/api/v3/scenarios/bind", ids:, bound:).body["missing"]
  end

  # TEMPORARY(2025.01): an engine without the bound flag only needs dont_keep_compatible to be called
  def release_without_bound_flag(user, version, ids, bound)
    return [] if bound

    engine = client(user, version)
    ids.each { |id| ApiScenario::SetCompatibility.dont_keep_compatible(engine, id) }
    []
  end

  def for_saved_scenario(user, saved_scenario, bound)
    call(user, saved_scenario.version, saved_scenario.all_scenario_ids, bound)
  end

  def supported?(version)
    Settings.versions_without_bound_flag.exclude?(version.tag)
  end

  def client(user, version)
    engine = OAuthApplication.find_by(uri: version.engine_url)
    MyEtm::Auth.client_for(user, engine, scopes: [ engine.scopes.to_s, SCOPE ])
  end
end
