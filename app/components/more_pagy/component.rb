module MorePagy
  class Component < ApplicationComponent
    include Pagy::Frontend

    option :pagy
  end
end
