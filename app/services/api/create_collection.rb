# frozen_string_literal: true

module Api
  # Creates a transition path from an API request.
  class CreateCollection
    include Dry::Monads[:result]
    include Dry::Monads::Do.for(:call)

    class Contract < Dry::Validation::Contract
      json do
        required(:title).filled(:string)
        optional(:area_code).filled(:string)
        optional(:end_year).filled(:integer)
        required(:version).filled(:string)
        optional(:interpolation).filled(:bool)
        optional(:scenario_ids).filled(min_size?: 1, max_size?: 100).each(:integer, gt?: 0)
        optional(:saved_scenario_ids).filled(min_size?: 1, max_size?: 100).each(:integer, gt?: 0)
      end

      rule(:scenario_ids, :saved_scenario_ids) do
        if values[:scenario_ids].nil? && values[:saved_scenario_ids].nil?
          key.failure('at least one scenario_id or saved_scenario_id should be present')
        end
      end
    end

    def call(user:, params:)
      params = yield validate(params)
      scenario_ids = params.delete(:scenario_ids)
      saved_scenario_ids = params.delete(:saved_scenario_ids)

      collection = user.collections.build(params)

      scenario_ids&.uniq&.each do |scenario_id|
        collection.scenarios.build(scenario_id:)
      end

      if saved_scenario_ids&.any?
        collection.saved_scenario_ids = saved_scenario_ids

        # If a transition path is created via this route we make sure to fill area_code and end_year
        if collection.interpolated?
          saved_scenario = SavedScenario.find_by(id: saved_scenario_ids.uniq.last)
          collection.area_code = saved_scenario.area_code if collection.area_code.blank?
          collection.end_year = saved_scenario.end_year if collection.end_year.blank?
        end
      end

      if collection.save
        Success(collection)
      else
        Failure(collection.errors)
      end
    end

    private

    def validate(params)
      result = Contract.new.call(params)
      result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
    end
  end
end
