# frozen_string_literal: true

# A saved scenario used by a Collection.
class CollectionSavedScenario < ApplicationRecord
  belongs_to :collection
  # Optional so an id resolving to nothing is answered once, by shared_access, rather than also
  # drawing belongs_to's own "must exist".
  belongs_to :saved_scenario, optional: true

  validate :shared_access

  private

  # A member the caller cannot use is refused the same way whether it does not exist, sits in the
  # bin, or belongs to someone else. Telling those apart would answer "does this id exist?" for any
  # id at all. `viewer?` already lets an admin through.
  def shared_access
    return if saved_scenario&.kept? && saved_scenario.viewer?(collection.user)

    errors.add(:base, :saved_scenario, message: "Saved scenario #{saved_scenario_id} not found")
  end
end
