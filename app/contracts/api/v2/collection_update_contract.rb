# frozen_string_literal: true

module Api
  module V2
    # Validates the request members for updating a Collection.
    #
    # version is absent deliberately: a collection is not repointed at another ETM version through
    # the general update action, so the base controller refuses it as a member this action will not
    # set. discarded is absent for the same reason, discard and restore being their own actions.
    class CollectionUpdateContract < Dry::Validation::Contract
      json do
        optional(:title).filled(:string)
        optional(:saved_scenario_ids).filled(min_size?: 1).each(:integer, gt?: 0)
      end
    end
  end
end
