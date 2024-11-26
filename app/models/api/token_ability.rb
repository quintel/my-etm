# frozen_string_literal: true

module Api
  # Describes the abilities of someone accessing the API with an access token or session.
  class TokenAbility
    include CanCan::Ability

    def initialize(token, user)
      scopes = extract_scopes(token)

      can :read, SavedScenario, private: false

      # scenarios:read
      # --------------

      return unless scopes.include?("scenarios:read")

      can :read, SavedScenario,
        id: SavedScenarioUser.where(user_id: user.id, role_id: User::Roles.index_of(:scenario_viewer)..).pluck(:saved_scenario_id)

      # scenarios:write
      # ---------------

      return unless scopes.include?("scenarios:write")

      can :create, SavedScenario

      # Unowned public scenario.
      can :update, SavedScenario, private: false
      cannot(:update, SavedScenario, private: false,
        id: SavedScenarioUser.pluck(:saved_scenario_id))

      # Self-owned scenario.
      can :update, SavedScenario,
        id: SavedScenarioUser.where(user_id: user.id, role_id: User::Roles.index_of(:scenario_collaborator)..).pluck(:saved_scenario_id)

      # Actions that involve reading one scenario and writing to another.
      can :clone, SavedScenario, private: false
      can :clone, SavedScenario,
        id: SavedScenarioUser.where(user_id: user.id, role_id: User::Roles.index_of(:scenario_collaborator)..).pluck(:saved_scenario_id)

      # scenarios:delete
      # ----------------

      return unless scopes.include?("scenarios:delete")

      can :destroy, SavedScenario,
        id: SavedScenarioUser.where(user_id: user.id, role_id: User::Roles.index_of(:scenario_owner)).pluck(:saved_scenario_id)
    end

    private

    def extract_scopes(token)
      if token.respond_to?(:scopes)         # doorkeeper_token
        token.scopes
      elsif token.is_a?(Hash)
        token[:scopes] || token["scopes"] || []  # decoded_token
      else
        []
      end
    end
  end
end
