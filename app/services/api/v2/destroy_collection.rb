
# frozen_string_literal: true

module Api
  module V2
    # Destroys from an API request.
    class DestroyCollection
      include Dry::Monads[:result]
      include Dry::Monads::Do.for(:call)

      def call(collection:)
        collection.destroy ? Success(collection) : Failure(collection.errors)
      end
    end
  end
end
