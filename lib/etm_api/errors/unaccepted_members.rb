# frozen_string_literal: true

module EtmApi
  module Errors
    # Raised when a request body carries members the action does not accept.
    class UnacceptedMembers < StandardError
      attr_reader :members

      def initialize(members)
        @members = members
        super("unaccepted members: #{members.join(', ')}")
      end
    end
  end
end
