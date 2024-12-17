# frozen_string_literal: true

module Login
  class ButtonComponent < ActionButtonComponent
    def initialize(form:)
      super(form:, type: :submit, color: :primary, size: :lg, class: "w-full !py-3 mt-5 bg-midnight-600 text-midnight-800")
    end
  end
end
