module History::Row
  class Component < ApplicationComponent
    include Turbo::FramesHelper

    option :user
    option :tag
    option :updated_at
    option :update_path
    option :updateable, default: proc { true }
    option :message, default: proc { '' }

    # thing for rendering action

    def css_classes
      @confirmed ? "" : "!text-midnight-450"
    end

    def disabled
      @updateble ? {} : { disabled: true }
    end

    def disabled_classes
      @updateble ? "text-sm hover:cursor-pointer" : "text-sm bg-none bg-midnight-300 border-midnight-300"
    end

    def destroy_classes
      @updateble ? "" : "!hover:text-midnight-400 !hover:cursor-initial pointer-events-none"
    end

    def destroy_text
      if @updateble
        t("saved_scenario_users.confirm_destroy.button")
      else
        t("saved_scenario_users.confirm_destroy.not_possible")
      end
    end
  end
end
