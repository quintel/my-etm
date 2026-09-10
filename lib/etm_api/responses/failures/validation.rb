module EtmApi
  module Responses
    module Failures
      # Every failing key, one error object each.
      class Validation < Base
        param :errors

        def error_objects
          return empty_failure if errors.empty?

          validation_failures(errors.to_hash).map do |path, message|
            SingularError.new(
              :unprocessable_content,
              EtmApi::Errors::Codes::VALIDATION_FAILED,
              message,
              member_source(path)
            )
          end
        end

        def status
          :unprocessable_content
        end

        private

        # A contract reports a failing collection member as { key => { index => [messages] } }
        def validation_failures(node, path = [])
          case node
          when Hash  then node.flat_map { |key, value| validation_failures(value, path + [ key ]) }
          when Array then node.flat_map { |value| validation_failures(value, path) }
          else [ [ path, node.to_s ] ]
          end
        end

        def empty_failure
          SingularError.new(
            :unprocessable_content,
            EtmApi::Errors::Codes::VALIDATION_FAILED,
            "The request could not be applied",
            nil
          )
        end
      end
    end
  end
end
