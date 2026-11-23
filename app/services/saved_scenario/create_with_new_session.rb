# frozen_string_literal: true

# Creates a SavedScenario whose Session MyETM creates itself: fresh from an area_code and end_year,
# or from a source the caller can read, interpolated when the end_year differs from the source's
#
# http_client - A client for ETEngine on the source's Version, or the requested one when there is no
#               source, granted on the source's Sessions.
# user        - The user creating the scenario, who owns it.
# attributes  - The validated request members.
# source      - The SavedScenario to copy, already authorised for reading, or nil.
#
# Returns a Dry::Monads::Result.
class SavedScenario::CreateWithNewSession
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]
  include Dry::Monads::Do.for(:call)

  param :http_client
  param :user
  param :attributes
  option :source, optional: true

  def call
    yield matching_version
    session = yield create_session

    SavedScenario::Create.call(http_client, saved_scenario_attributes(session), user)
  end

  private

  def matching_version
    return Success() if source.nil? || attributes[:version] == source.version.tag

    Failure(version: [ "must match the source's version, #{source.version.tag}" ])
  end

  # ETEngine's interpolation takes no privacy, so the saved scenario's callbacks set it there
  def create_session
    if interpolating?
      ApiScenario::Interpolate.call(http_client, source.scenario_id, attributes[:end_year])
    else
      ApiScenario::Create.call(http_client, session_attributes.merge(private: private?))
    end
  end

  def session_attributes
    source ? { scenario_id: source.scenario_id } : attributes.slice(:area_code, :end_year)
  end

  def interpolating?
    source&.interpolates_to?(attributes[:end_year])
  end

  def private?
    attributes.fetch(:private) { source ? source.private : user.private_scenarios }
  end

  def saved_scenario_attributes(session)
    attributes.slice(:title, :description, :version).merge(
      scenario_id: session["id"],
      area_code: session["area_code"],
      end_year: session["end_year"],
      private: private?
    )
  end
end
