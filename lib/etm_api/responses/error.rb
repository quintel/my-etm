module EtmApi
  module Responses
    class Error
      extend Dry::Initializer

      param :errors
      param :status

      # validate status, validate error pattern (should be of same type?)

      def self.render(errors:, status: )
        self.new(errors:, status:).render
      end

      def render
        render json: { errors: }, status:
      end
    end
  end
end
