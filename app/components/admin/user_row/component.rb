module Admin::UserRow
  class Component < ApplicationComponent
    option :user
    option :confirmed, default: proc { true }
    option :confirm_path
    option :path

    def css_classes
      @confirmed ? "" : "!text-midnight-450"
    end
  end
end
