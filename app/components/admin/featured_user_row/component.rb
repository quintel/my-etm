module Admin::FeaturedUserRow
  class Component < Admin::UserRow::Component
    include ButtonHelper

    option :user
    option :confirmed, default: proc { true }
    option :confirm_path, default: proc { true }
    option :path

    def css_classes
      "!text-midnight-450"
    end
  end
end
