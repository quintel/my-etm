module EtmApi
  module Responses
    module Failures
      class Base
        extend Dry::Initializer

        SingularError = Struct.new(:status, :code, :detail, :source) do
          def to_h
            object = { status: Rack::Utils.status_code(status), code: code.to_s, detail: detail }
            object[:source] = source if source
            object
          end
        end

        def self.render(*params)
          response = self.new(*params)

          EtmApi::Responses::Error.render(
            errors: response.error_objects, status: response.status
          )
        end

        def error_objects
          # empty SingularError obj
        end

        def status
          :unprocessable_content
        end
      end
    end
  end
end
