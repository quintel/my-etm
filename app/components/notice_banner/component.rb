module NoticeBanner
  class Component < ApplicationComponent
    option :text
    option :path, default: proc { "" }
    option :button_text, default: proc { "" }
    option :icon, default: proc { "information-circle" }
    option :warning, default: proc { false }

    def text_color
      if warning
        "text-midnight-200"
      else
        "text-midnight-800"
      end
    end

    def icon_color
      if warning
        "text-midnight-200"
      else
        "text-midnight-450"
      end
    end

    def bg_color
      if warning
        "bg-red-600"
      else
        "bg-midnight-300"
      end
    end
  end
end
