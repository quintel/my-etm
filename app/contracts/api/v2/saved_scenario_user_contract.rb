# frozen_string_literal: true

module Api
  module V2
    # Validates one submitted membership for the actions that set a role.
    #
    # A member is addressed by email, so it is required rather than optional: an item naming nobody
    # asks for nothing. Its failures are reported per item, since the rest of the batch is unaffected
    # by one item the caller got wrong.
    class SavedScenarioUserContract < Dry::Validation::Contract
      ROLES = User::Roles.roles.values.map(&:to_s).freeze

      json do
        required(:email).filled(:string)
        required(:role).filled(:string, included_in?: ROLES)
      end
    end
  end
end
