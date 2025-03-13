# frozen_string_literal: true

module Api
  # Describes the abilities of someone accessing the API with an access token or session.
  class TokenAbility
    include CanCan::Ability

    def initialize(token, user)
      scopes = extract_scopes(token)

      can :read, SavedScenario, private: false

      # scenarios:read
      return unless scopes.include?("scenarios:read")

      can :read, SavedScenario,
        id: saved_scenario_ids_for(user, :scenario_viewer, range: true)

      can :read, Collection,
        id: Collection.where(user_id: user.id).pluck(:id)

      # scenarios:write
      return unless scopes.include?("scenarios:write")

      can :create, SavedScenario
      can :create, Collection

      can :update, SavedScenario,
        id: saved_scenario_ids_for(user, :scenario_collaborator, range: true)

      can :update, Collection,
        id: Collection.where(user_id: user.id).pluck(:id)

      # scenarios:delete
      return unless scopes.include?("scenarios:delete")

      can :destroy, SavedScenario,
        id: saved_scenario_ids_for(user, :scenario_owner)

      can :destroy, Collection,
        id: Collection.where(user_id: user.id).pluck(:id)
    end

    private

    # Helper method to extract saved scenario IDs for a user given a role.
    # When range is true, the query will use a range starting from the role's index.
    def saved_scenario_ids_for(user, role, range: false)
      role_value = User::Roles.index_of(role)
      conditions = { user_id: user.id }
      if range
        conditions[:role_id] = role_value..Float::INFINITY
      else
        conditions[:role_id] = role_value
      end
      SavedScenarioUser.where(conditions).pluck(:saved_scenario_id)
    end

    def extract_scopes(token)
      if token.respond_to?(:scopes)               # doorkeeper_token
        token.scopes
      elsif token.is_a?(Hash)
        token[:scopes] || token["scopes"] || []   # decoded_token
      else
        []
      end
    end
  end
end
