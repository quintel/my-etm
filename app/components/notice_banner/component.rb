module NoticeBanner
  class Component < ApplicationComponent
    option :text
    option :path, default: proc { "" }
    option :button_text, default: proc { "" }
    option :icon, default: proc { 'information-circle' }
  end
end
