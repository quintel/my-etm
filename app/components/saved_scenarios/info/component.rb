module SavedScenarios::Info
  class Component < ApplicationComponent
    include ButtonHelper

    option :path
    option :saved_scenario
    option :time
    option :button_title

    def link_to_scenario
      params = {
        scenario_id: @saved_scenario.scenario_id,
        title: @saved_scenario.title
      }

      "#{@path}?#{params.to_query}"
    end
  end
end
