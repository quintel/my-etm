module Admin
  class SavedScenariosController < ApplicationController
    include AdminController

    def index
      @saved_scenarios = SavedScenario.available
        .includes(:featured_scenario, :users)
        .order('updated_at DESC')
    end
  end
end
