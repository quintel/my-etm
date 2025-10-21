# frozen_string_literal: true

# A saved scenario used by a Collection.
class CollectionSavedScenario < ApplicationRecord
  belongs_to :collection, touch: true
  belongs_to :saved_scenario

  validate :shared_access

  private

  def shared_access
    return if saved_scenario.viewer?(collection.user)

    errors.add(:base, :user, message: 'User must have access to both the Collection and the Saved Sceanrio')
  end
end
