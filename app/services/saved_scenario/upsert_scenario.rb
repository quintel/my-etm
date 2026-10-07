# frozen_string_literal: true

# Adds the current scenario to the provided SavedScenario, and adding the old
# scenario to history.
#
# saved_scenario  - The scenario to be updated
# scenario_id     - The ID of the scenario to be saved.
# settings        - Optional extra scenario data to be sent to ETEngine when
#                   creating the new API scenario.
# user            - The user acting, who owns the token that binds the Session
#
# Returns a ServiceResult with the saved scenario.
class SavedScenario::UpsertScenario
  extend Dry::Initializer
  include Service

  param :http_client
  param :saved_scenario
  param :scenario_id
  param :settings, default: proc { {} }
  option :user

  def call
    saved_scenario.tap do |ss|
      evicted = ss.add_id_to_history(ss.scenario_id)
      ss.scenario_id = scenario_id

      unless ss.valid?
        unprotect
        return failure
      end

      bound = bind(evicted)
      return bound if bound.failure?

      protect

      set_roles

      tag_new_version

      ss.save
      saved_scenario.scenario_id = scenario_id
    end

    ServiceResult.success(saved_scenario)
  end

  private

  # Binds the new current Session, and unbinds the evicted Session if there was one
  def bind(evicted)
    result = ApiScenario::SetBound.call(user, saved_scenario.version, [ scenario_id ], true)
    return result if result.failure? || evicted.nil?

    ApiScenario::SetBound.call(user, saved_scenario.version, [ evicted ], false)
  end

  def protect
    ApiScenario::SetCompatibility.keep_compatible(http_client, scenario_id)
  end

  def unprotect
    ApiScenario::SetCompatibility.dont_keep_compatible(http_client, scenario_id)
  end

  def set_roles
    ApiScenario::SetRoles.to_preset(
      http_client,
      scenario_id,
      saved_scenario: saved_scenario
    )
  end

  def tag_new_version
    ApiScenario::VersionTags::Create.call(http_client, scenario_id, "")
  end

  def failure
    ServiceResult.failure(saved_scenario.errors.map(&:full_message))
  end

  # TODO: keep in ETModel
  # def api_scenario
  #   api_response.value
  # end

  # def api_response
  #   @api_response ||= CreateAPIScenario.call(http_client, settings.merge(scenario_id:))
  # end

  # def failure?
  #   api_response.failure?
  # end
end
