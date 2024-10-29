module SidebarItem
  class Component < ApplicationComponent
    option :path
    option :title
    option :icon
    option :active, default: proc { false }
    option :text, default: proc { "text-midnight-450" }

    def css_classes
      if @active
        "text-midnight-800 hover:text-midnight-800"
      else
        "#{@text} hover:text-midnight-800"
      end
    end
  end
end
