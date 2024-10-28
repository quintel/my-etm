module SavedScenario::Users
  # Returns a collection of SavedScenarioUsers
  def owners
    saved_scenario_users.where(role_id: User::Roles.index_of(:scenario_owner))
  end

  # Returns a collection of SavedScenarioUsers
  def collaborators
    saved_scenario_users.where(role_id: User::Roles.index_of(:scenario_collaborator))
  end

  # Returns a collection of SavedScenarioUsers
  def viewers
    saved_scenario_users.where(role_id: User::Roles.index_of(:scenario_viewer))
  end

  def single_owner?
    owners.count == 1
  end

  # Returns true if the user is owner
  def owner?(user)
    return false if user.blank?

    ssu = saved_scenario_users.find_by(user_id: user.id)
    ssu.present? && ssu.role_id == User::Roles.index_of(:scenario_owner)
  end

  # Returns true if the user is collaborator
  def collaborator?(user)
    return false if user.blank?

    ssu = saved_scenario_users.find_by(user_id: user.id)
    ssu.present? && ssu.role_id >= User::Roles.index_of(:scenario_collaborator)
  end

  # Returns true if the user is viewer
  def viewer?(user)
    return false if user.blank?

    return true if user.admin?

    ssu = saved_scenario_users.find_by(user_id: user.id)
    ssu.present? && ssu.role_id >= User::Roles.index_of(:scenario_viewer)
  end

  # Convenience method to quickly set the owner for a scenario, e.g. when creating it as
  # Scenario.create(user: User). Only works to set the first user, returns false otherwise.
  def user=(user)
    return unless user.present? && saved_scenario_users.empty? && valid?

    SavedScenarioUser.create(
      saved_scenario: self,
      user: user,
      role_id: User::Roles.index_of(:scenario_owner)
    )
  end
end
