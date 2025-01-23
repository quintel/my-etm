module History::Row
  class Component < ViewComponent::Base
    include Turbo::FramesHelper

    def initialize(historical_version:, tag:, update_path:)
      @historical_version = historical_version
      @tag = tag
      @update_path = update_path
    end

    def description
      @historical_version.description.presence || t("history.empty_message")
    end
  end
end
