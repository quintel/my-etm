# frozen_string_literal: true

# Discards or undiscards a SavedScenario. Its Sessions are unbound or rebound in ETEngine first, and
# nothing is written when that fails.
#
# saved_scenario - The scenario to discard or undiscard.
# discarded      - true to discard, false to undiscard.
# user           - The user acting, who owns the engine token.
#
# Returns a Dry::Monads::Result with the saved scenario. A failure carries the record's errors, or
# an [:upstream, messages] pair when ETEngine failed
class SavedScenario::SetDiscarded
  extend Dry::Initializer
  include Service
  include Dry::Monads[:result]

  param :saved_scenario
  param :discarded
  param :user

  def call
    return Success(saved_scenario) if saved_scenario.discarded? == discarded
    return Failure([ :upstream, bind_result.errors ]) if bind_result.failure?

    saved_scenario.discarded_at = discarded ? Time.current : nil
    saved_scenario.save(touch: false) ? Success(saved_scenario) : Failure(saved_scenario.errors)
  end

  private

  def bind_result
    @bind_result ||= ApiScenario::SetBound.for_saved_scenario(user, saved_scenario, !discarded)
  end
end
