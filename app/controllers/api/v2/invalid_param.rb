# frozen_string_literal: true

module Api
  module V2
    # Raised when a parameter is present but the wrong shape.
    class InvalidParam < StandardError
      attr_reader :pointer

      def initialize(pointer, message)
        @pointer = pointer
        super(message)
      end
    end
  end
end
