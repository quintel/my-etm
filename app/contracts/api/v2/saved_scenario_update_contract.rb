# frozen_string_literal: true

module Api
  module V2
    # Validates the request members for updating a SavedScenario.
    #
    # scenario_id and version are absent deliberately: neither is repointed through the general
    # update action, so the base controller refuses them as members this action will not set.
    class SavedScenarioUpdateContract < Dry::Validation::Contract
      json do
        optional(:title).filled(:string)
        optional(:area_code).filled(:string)
        optional(:end_year).filled(:integer)
        optional(:description).maybe(:string)
        optional(:private).filled(:bool)
      end
    end
  end
end
