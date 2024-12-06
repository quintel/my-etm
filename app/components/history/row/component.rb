module History::Row
  class Component < ApplicationComponent
    include Turbo::FramesHelper

    option :historical_version
    option :tag
    option :update_path
  end
end
