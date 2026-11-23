# frozen_string_literal: true

module Api
  module V4
    # Validates the request members for creating a SavedScenario, either as:
    # - an existing scenario_id with its area_code and end_year
    # - a source to copy
    # - an area_code and end_year
    class SavedScenarioCreateContract < Dry::Validation::Contract
      json do
        optional(:scenario_id).filled(:integer)
        optional(:source).filled(:integer)
        required(:title).filled(:string)
        optional(:area_code).filled(:string)
        optional(:end_year).filled(:integer)
        required(:version).filled(:string)
        optional(:description).maybe(:string)
        optional(:private).filled(:bool)
      end

      rule(:source) do
        key.failure("cannot be given with a scenario_id") if key? && values.key?(:scenario_id)
      end

      rule(:area_code) do
        key.failure("cannot be given with a source") if key? && values.key?(:source)
      end

      rule do
        next if values.key?(:source)

        %i[area_code end_year].each { |member| key(member).failure("is missing") unless values.key?(member) }
      end
    end
  end
end
