module Collections::ScenarioPicker
  class Component < ApplicationComponent
    option :scenario
    option :hidden, default: proc { false }
  end
end
