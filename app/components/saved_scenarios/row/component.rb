module SavedScenarios::Row
  class Component < ApplicationComponent
    option :path
    option :saved_scenario

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user.initials.capitalize
    end

    def first_owner
      @saved_scenario.owners.first
    end
  end
end
