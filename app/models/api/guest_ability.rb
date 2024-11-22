# frozen_string_literal: true

module Api
  # Describes the abilities of someone accessing the API without a token.
  class GuestAbility
    include CanCan::Ability

    def initialize
      can :create, SavedScenario
      can :read,   SavedScenario, private: false
      can :update, SavedScenario, private: false
    end
  end
end
