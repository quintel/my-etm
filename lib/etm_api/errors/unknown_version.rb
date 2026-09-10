# frozen_string_literal: true

module EtmApi
  module Errors
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
