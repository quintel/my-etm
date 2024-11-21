module Admin::UserRow
  class Component < ApplicationComponent
    include ButtonHelper

    option :user
    option :confirmed, default: proc { true }
    option :confirm_path
    option :path

    def css_classes
      @confirmed ? "" : "!text-midnight-450"
    end
  end
end
