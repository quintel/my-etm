# frozen_string_literal: true

module Login
  class DeviseFooterLinkComponent < ApplicationComponent
    include CssClasses

    DEFAULT_CLASSES = %w[
      inline-block
      px-2 py-1
      rounded
      text-midnight-800 text-sm
      transition

      active:bg-midnight-600 active:text-midnight-800
      hover:bg-midnight-600 hover:text-midnight-800
    ].freeze

    def initialize(path:, **attributes)
      @path = path
      @attributes = merge_attributes(attributes)
    end
  end
end
