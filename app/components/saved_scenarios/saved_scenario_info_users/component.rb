module SavedScenarioInfoUsers
  class Component < ApplicationComponent
    option :users
    option :title

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user.user_email.first.capitalize
    end
  end
end
