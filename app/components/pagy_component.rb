# frozen_string_literal: true

class PagyComponent < ApplicationComponent
  option :pagy_objects, default: proc { nil }
end
