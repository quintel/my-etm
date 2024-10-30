# frozen_string_literal: true

class Identity::SidebarItemComponent < ApplicationComponent
  option :path
  option :title
  option :explanation
  option :active, default: proc { false }
  option :icon, default: proc { 'identification' }

  def css_classes
    if @active
      "text-midnight-800 rounded-md bg-midnight-600 hover:text-midnight-800"
    else
      "text-midnight-450 hover:text-midnight-800"
    end
  end
end
