module Collections::Info
  class Component < ApplicationComponent
    include ButtonHelper

    option :path
    option :collection
    option :time
    option :button_title
  end
end
