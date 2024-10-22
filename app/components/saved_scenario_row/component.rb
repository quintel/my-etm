module SavedScenarioRow
  class Component < ApplicationComponent
    option :path
    option :saved_scenario

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user.user_email.first.capitalize
    end

    def first_owner
      @saved_scenario.owners.first
    end
  end
end
