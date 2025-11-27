module Admin::SelectableSavedScenario
  class Component < ApplicationComponent
    option :form
    option :path
    option :saved_scenario
    option :access, default: proc { true }

    # Initials to show
    def initials_for(saved_scenario_user)
      saved_scenario_user&.initials&.capitalize || "?"
    end

    def first_owner
      @saved_scenario.owners.first
    end

    def css_classes
      unless @access
        "pointer-events-none bg-gray-100 hover:bg-gray-100 hover:cursor-initial"
      end
    end
  end
end
