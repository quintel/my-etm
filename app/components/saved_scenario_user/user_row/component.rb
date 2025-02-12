module SavedScenarioUser::UserRow
  class Component < ApplicationComponent
    include Turbo::FramesHelper

    option :user
    option :destroy_path
    option :update_path
    option :destroyable, default: proc { true }
    option :confirmed, default: proc { true }

    def css_classes
      @confirmed ? "" : "!text-midnight-450"
    end

    def disabled
      @destroyable ? {} : { disabled: true }
    end

    def disabled_classes
      @destroyable ? "text-sm hover:cursor-pointer" : "text-sm bg-none bg-midnight-300 border-midnight-300"
    end

    def destroy_classes
      @destroyable ? "" : "!hover:text-midnight-400 !hover:cursor-initial pointer-events-none"
    end

    def destroy_text
      if @destroyable
        t("saved_scenario_users.confirm_destroy.button")
      else
        t("saved_scenario_users.confirm_destroy.not_possible")
      end
    end
  end
end
