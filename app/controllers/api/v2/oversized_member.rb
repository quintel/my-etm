# frozen_string_literal: true

module Api
  module V2
    # Raised when a request body carries more items in one member than a call may.
    class OversizedMember < StandardError
      attr_reader :member

      def initialize(member)
        @member = member
        super("oversized member: #{member}")
      end
    end
  end
end
