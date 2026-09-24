# frozen_string_literal: true

module EtmApi
  module Errors
    # Raised when a request body carries members the action does not accept.
    class UnacceptedMembers < StandardError
      attr_reader :members, :path

      # `path` locates what carried them, so a batch item can say which position was at fault.
      def initialize(members, path: [])
        @members = members
        @path = path
        super("unaccepted members: #{members.join(', ')}")
      end
    end
  end
end
