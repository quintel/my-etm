module Collections::ScenarioButton
  class Component < ApplicationComponent
    option :saved_scenario

    def initials_for(user)
      user&.initials&.capitalize || "?"
    end

    def first_owner
      @saved_scenario.owners.first
    end

    def scenario_details
      area = t("areas.#{@saved_scenario.area_code}")
      "#{area}, #{@saved_scenario.end_year}"
    end
  end
end
