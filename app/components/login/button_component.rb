# frozen_string_literal: true

module Login
  class ButtonComponent < ActionButtonComponent
    def initialize(form:)
      super(form:, type: :submit, color: :success, size: :lg, class: "w-full !py-3 mt-5")
    end
  end
end
