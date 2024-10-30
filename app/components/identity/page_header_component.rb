# frozen_string_literal: true

class Identity::PageHeaderComponent < ApplicationComponent
  renders_one :actions

  option :message
end
