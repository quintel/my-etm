module History::Row
  class Component < ApplicationComponent
    include Turbo::FramesHelper

    option :historical_version
    option :tag
    option :update_path

    def description
      if @historical_version.description.presence
        @historical_version.description
      else
        t("history.empty_message")
      end
    end
  end
end
