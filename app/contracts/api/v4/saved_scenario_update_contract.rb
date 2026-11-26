# frozen_string_literal: true

module Api
  module V4
    # Validates the request members for updating a SavedScenario.
    class SavedScenarioUpdateContract < Dry::Validation::Contract
      json do
        optional(:title).filled(:string)
        optional(:description).maybe(:string)
        optional(:private).filled(:bool)
      end
    end
  end
end
