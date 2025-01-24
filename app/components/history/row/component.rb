module History::Row
  class Component < ViewComponent::Base
    include Turbo::FramesHelper
    include ButtonHelper

    def initialize(historical_version:, tag:, update_path:, restore_path:, owner: false, collaborator: false, restorable: true)
      @historical_version = historical_version
      @tag = tag
      @update_path = update_path
      @restore_path = restore_path
      @owner = owner
      @collaborator = collaborator
      @restorable = restorable
    end

    def description
      @historical_version.description.presence || t("history.empty_message")
    end
  end
end
