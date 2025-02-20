module SavedScenarios::Info
  class Component < ApplicationComponent
    include ButtonHelper

    option :path
    option :saved_scenario
    option :time
    option :button_title
    option :with_user

    def link_to_scenario
      params = {
        scenario_id: @saved_scenario.scenario_id,
        title: @saved_scenario.title,
        # Let's etmodel know to check for signing in
        current_user: @with_user
      }

      "#{@path}?#{params.to_query}"
    end
  end
end
