module SidebarItem
  class ProfileItemComponent < ApplicationComponent
    option :path
    option :icon
    option :data, default: proc { {} }
  end
end
