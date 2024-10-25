# frozen_string_literal: true

# Describes the abilities of users accessing the web interface.
class Ability
  include CanCan::Ability

  def initialize(user)
    can :manage, :all if user&.admin?

    can :read, SavedScenario, private: false

    return unless user

    can :create,  SavedScenario
    can :read,    SavedScenario, id: SavedScenario.viewable_by?(user).pluck(:id)
    can :update,  SavedScenario, id: SavedScenario.collaborated_by?(user).pluck(:id)
    can :destroy, SavedScenario, id: SavedScenario.owned_by?(user).pluck(:id)

    can :destroy, Collection, user_id: user.id
  end
end
