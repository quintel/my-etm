module Collections::Title
  class Component < ApplicationComponent
    include ButtonHelper

    option :path
    option :title
    option :editable

    def css_classes
      if @editable
        'hover:underline
        focus:outline-none
        focus:border
        focus:rounded-md
        focus:px-2'
      end
    end

    def actions
      if @editable
        'blur->editable-title#update
        keydown.enter->editable-title#update'
      end
    end
  end
end
