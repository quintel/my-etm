module SidebarItem
  class ProfileComponent < Component
    def css_classes
      if @active
        "undeline text-midnight-800"
      else
        "text-midnight-800"
      end
    end
  end
end
