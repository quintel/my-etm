# frozen_string_literal: true

# Sets or clears ETEngine's `bound` flag, which marks a Session as held by an undiscarded saved
# scenario, as its current Session or a snapshot.
#
# Returns a ServiceResult whose value lists the IDs ETEngine has no Session for
module ApiScenario::SetBound
  module_function

  SCOPE = "scenarios:bind"

  def call(user, version, ids, bound)
    ServiceResult.success(call!(user, version, ids, bound))
  rescue Faraday::Error => e
    Sentry.capture_exception(e)
    ServiceResult.failure("Failed to update the scenario in ETEngine")
  end

  # Raises a Faraday::Error when ETEngine fails
  def call!(user, version, ids, bound)
    return [] unless supported?(version)

    client(user, version).put("/api/v3/scenarios/bind", ids:, bound:).body["missing"]
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
