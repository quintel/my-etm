# frozen_string_literal: true

module Hovercard
  class Component < ApplicationComponent
    option :path
    option :text, default: proc { "" }
  end
end
