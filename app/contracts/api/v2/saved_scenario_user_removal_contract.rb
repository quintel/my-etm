# frozen_string_literal: true

module Api
  module V2
    # Validates one submitted membership for removal, which needs only the address it is held by.
    #
    # role is accepted and ignored, so an item fetched from the index can be sent straight back.
    class SavedScenarioUserRemovalContract < Dry::Validation::Contract
      json do
        required(:email).filled(:string)
        optional(:role).filled(:string)
      end
    end
  end
end
