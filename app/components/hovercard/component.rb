# frozen_string_literal: true

module Hovercard
  class Component < ApplicationComponent
    option :path
    option :text, default: proc { "" }
    option :placement_class, default: proc { 'right-2' }
  end
end
