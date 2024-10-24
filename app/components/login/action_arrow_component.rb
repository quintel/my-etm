# frozen_string_literal: true

module Login
  class ActionArrowComponent < ApplicationComponent
    def call
      heroicon @icon, options: { class: 'flex-shrink-0 ml-1 mt-px group-hover:translate-x-1 group-active:translate-x-1 transition duration-300', aria_hidden: true }
    end
  end
end
