# frozen_string_literal: true

module Api
  module V2
    # Validates the request members for creating a SavedScenario.
    class SavedScenarioCreateContract < Dry::Validation::Contract
      json do
        required(:scenario_id).filled(:integer)
        required(:title).filled(:string)
        required(:area_code).filled(:string)
        required(:end_year).filled(:integer)
        required(:version).filled(:string)
        optional(:description).maybe(:string)
        optional(:private).filled(:bool)
      end
    end
  end
end
