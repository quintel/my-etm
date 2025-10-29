# frozen_string_literal: true

module Api
  # Creates a transition path from an API request.
  class UpdateCollection
    include Dry::Monads[:result]
    include Dry::Monads::Do.for(:call)

    class Contract < Dry::Validation::Contract
      json do
        optional(:title).filled(:string)
        optional(:version).filled(:string)
        optional(:area_code).filled(:string)
        optional(:end_year).filled(:integer)
        optional(:scenario_ids).filled(min_size?: 1, max_size?: 100).each(:integer, gt?: 0)
        optional(:saved_scenario_ids).filled(min_size?: 1, max_size?: 100).each(:integer, gt?: 0)
      end
    end

    def call(collection:, params:)
      params = yield validate(params)
      scenario_ids = params.delete(:scenario_ids)
      saved_scenario_ids = params.delete(:saved_scenario_ids)

      collection.attributes = params

      Collection.transaction do
        update_scenarios(collection, scenario_ids.uniq) if scenario_ids&.any?
        update_saved_scenarios(collection, saved_scenario_ids.uniq) if saved_scenario_ids&.any?
        collection.save!
      rescue ActiveRecord::RecordInvalid
        return Failure(collection.errors)
      end

      Success(collection.reload)
    end

    private

    def validate(params)
      result = Contract.new.call(params)
      result.success? ? Success(result.to_h) : Failure(result.errors.to_h)
    end

    def update_scenarios(collection, scenario_ids)
      existing_ids = collection.scenarios.pluck(:scenario_id)
      new_ids      = scenario_ids - existing_ids
      delete_ids   = existing_ids - scenario_ids

      collection.scenarios.delete_by(scenario_id: delete_ids)
      new_ids.each { |id| collection.scenarios.create!({ scenario_id: id }) }
    end

    def update_saved_scenarios(collection, saved_scenario_ids)
      existing_ids = collection.saved_scenarios.pluck(:saved_scenario_id)
      delete_ids   = existing_ids - saved_scenario_ids

      collection.collection_saved_scenarios.delete_by(saved_scenario_id: delete_ids)
      saved_scenario_ids.each.with_index(1) { |id, i| collection.collection_saved_scenarios.find_or_create_by(saved_scenario_id: id).update!(saved_scenario_order: i) }
    end
  end
end
