# frozen_string_literal: true

class PagyComponent < ApplicationComponent
  include Pagy::Frontend

  option :pagy_objects, default: proc { nil }
end
