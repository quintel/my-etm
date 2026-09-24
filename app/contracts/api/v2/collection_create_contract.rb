# frozen_string_literal: true

module Api
  module V2
    # Validates the request members for creating a Collection.
    #
    # area_code, end_year, interpolation and scenario_ids are absent deliberately: v2 builds a
    # collection from saved scenarios alone, so the base controller refuses them as members this
    # action will not set.
    #
    # The upper bound on saved_scenario_ids is the base controller's, which caps every declared
    # list at BATCH_LIMIT before a contract sees it.
    class CollectionCreateContract < Dry::Validation::Contract
      json do
        required(:title).filled(:string)
        required(:version).filled(:string)
        required(:saved_scenario_ids).filled(min_size?: 1).each(:integer, gt?: 0)
      end
    end
  end
end
