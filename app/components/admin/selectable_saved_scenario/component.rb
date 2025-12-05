module Admin::SelectableSavedScenario
  class Component < ApplicationComponent
    option :form
    option :path
    option :saved_scenario
    option :access, default: proc { true }

    def css_classes
      unless @access
        "pointer-events-none bg-gray-100 hover:bg-gray-100 hover:cursor-initial"
      end
    end
  end
end
