# frozen_string_literal: true

# Permanently deletes a SavedScenario and unbinds its Sessions in ETEngine. The scenario is kept
# when either step fails, so a Session should not be left unbound while held by a scenario
#
# saved_scenario - The scenario to delete.
# user           - The user acting, who owns the engine token.
#
# Returns a Dry::Monads::Result with the saved scenario. A failure carries the record's errors, or
# an [:upstream, messages] pair when ETEngine failed
class SavedScenario::Purge
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :saved_scenario
  param :user

  def call
    result = nil

    SavedScenario.transaction do
      result = destroy_and_unbind
      raise ActiveRecord::Rollback if result.failure?
    end

    result
  end

  private

  def destroy_and_unbind
    return Failure(saved_scenario.errors) unless saved_scenario.destroy

    unbound = ApiScenario::SetBound.for_saved_scenario(user, saved_scenario, false)
    unbound.successful? ? Success(saved_scenario) : Failure([ :upstream, unbound.errors ])
  end
end
