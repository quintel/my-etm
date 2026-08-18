# frozen_string_literal: true

# A saved scenario used by a Collection.
class CollectionSavedScenario < ApplicationRecord
  belongs_to :collection
  belongs_to :saved_scenario

  validate :shared_access

  private

  def shared_access
    return errors.add(:base, :saved_scenario, message: "Saved scenario not found") if saved_scenario.nil?
    return if saved_scenario.viewer?(collection.user)

    errors.add(:base, :user, message: "User must have access to both the Collection and the Saved Scenario")
  end
end
