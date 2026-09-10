# frozen_string_literal: true

module EtmApi
  module Responses
    # One object in the `errors` array. `source` is omitted rather than null when there is nothing
    # to point at, since a pointer is only meaningful for a member the caller actually sent.
    module ErrorObject
      module_function

      def build(status:, code:, detail:, source: nil)
        object = { status: Rack::Utils.status_code(status), code: code.to_s, detail: detail }
        object[:source] = source if source
        object
      end
    end
  end
end
