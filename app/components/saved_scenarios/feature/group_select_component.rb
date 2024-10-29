module SavedScenarios::Feature
  class GroupSelectComponent < ApplicationComponent
    option :form

    def featured_scenario_groups_collection
      FeaturedScenario::GROUPS.map { |option| [ t("scenario.#{option}"), option ] }
    end
  end
end
