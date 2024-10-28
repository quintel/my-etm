module SavedScenarios::InfoUsers
  class Component < ApplicationComponent
    option :users
    option :title

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user.initials.capitalize
    end
  end
end
