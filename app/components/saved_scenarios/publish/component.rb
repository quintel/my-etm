module SavedScenarios::Publish
  class Component < ApplicationComponent
    option :path_on
    option :path_off
    option :icon_on
    option :icon_off
    option :title
    option :status

    def path
      @status ? @path_on : @path_off
    end

    def icon
      @status ? @icon_on : @icon_off
    end
  end
end
