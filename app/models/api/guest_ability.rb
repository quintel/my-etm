# frozen_string_literal: true

module Api
  # Describes the abilities of someone accessing the API without a token.
  class GuestAbility
    include CanCan::Ability

    def initialize
      can :read,   SavedScenario, private: false
      can :read,   Collection, id: public_collection_ids
    end

    private

    # Collections every one of whose scenarios is public. A collection is no more readable than the
    # least readable scenario in it, and a guest can read only the public ones.
    def public_collection_ids
      Collection.fully_readable_by(nil).pluck(:id)
    end
  end
end
