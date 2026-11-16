# frozen_string_literal: true

# Opens Sessions by ID for an ETM app whose cookie lacks a grant: records the caller's current role
# on each Scenario holding one of them as its current Session, on that Scenario's Version, then
# returns. To be used by routes that reach ETEngine without passing through MyETM's open:
# Collections' by session ID and ETModel's direct loads.
class OpenSessionsController < ApplicationController
  # GET /saved_scenarios/open?session_ids[]=1&session_ids[]=2&return_to=<url>
  def show
    session_ids = params.expect(session_ids: [])
    return_to = EtmAppRedirects.validate(params.expect(:return_to))
    return head(:bad_request) unless return_to

    grant_sessions(session_ids) if current_user
    redirect_to(return_to, allow_other_host: true)
  end

  private

  # Re-deriving drops the entry of a lost role
  def grant_sessions(session_ids)
    entries = RederiveScenarioAccess.entries_for(current_user.id, session_ids)
    update_scenario_access { |access| access.grant(entries) }
  end
end
