# frozen_string_literal: true

module EtmApi
  module Responses
    # Turns a validation error hash into the error objects that describe it.
    module Validation
      module_function

      # One [path, message] pair per failure. A contract reports a failing collection member as
      # { key => { index => [messages] } }, so the nesting is walked rather than assumed flat.
      def failures(node, path = [])
        case node
        when Hash  then node.flat_map { |key, value| failures(value, path + [ key ]) }
        when Array then node.flat_map { |value| failures(value, path) }
        else [ [ path, node.to_s ] ]
        end
      end

      # `errors` must hold at least one object, and a failure can arrive carrying none.
      def unspecified_failure
        ErrorObject.build(
          status: :unprocessable_content,
          code: Errors::Codes::VALIDATION_FAILED,
          detail: "The request could not be applied"
        )
      end
    end
  end
end
