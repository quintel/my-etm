module SavedScenarios::NavItem
  class Component < ApplicationComponent
    option :path
    option :title
    option :icon
    option :active, default: proc { false }
    option :static, default: proc { false }

    def css_classes
      if @active
        "text-midnight-800 rounded-md bg-midnight-600 hover:text-midnight-800"
      elsif @static
        "text-midnight-800 hover:underline"
      else
        "text-midnight-450 hover:text-midnight-800"
      end
    end
  end
end
