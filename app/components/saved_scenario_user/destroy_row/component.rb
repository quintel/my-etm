module SavedScenarioUser::DestroyRow
  class Component < ApplicationComponent
    include Turbo::FramesHelper
    include ButtonHelper

    option :user
    option :path
  end
end
