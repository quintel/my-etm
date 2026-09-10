# frozen_string_literal: true

module Api
  module V2
    # Raised when a request names a version tag that does not resolve.
    class UnknownVersion < StandardError
      attr_reader :member

      def initialize(member)
        @member = member
        super("unknown version: #{member}")
      end
    end
  end
end
