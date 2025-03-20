# frozen_string_literal: true

module Api
  # Describes the abilities of someone accessing the API with an access token or session.
  class TokenAbility
    include CanCan::Ability

    def initialize(token, user)
      @scopes = extract_scopes(token)
      @user   = user

      allow_public_read
      allow_read if read_scope?
      allow_write if write_scope?
      allow_delete if delete_scope?
    end

    private

    def extract_scopes(token)
      if token.respond_to?(:scopes)               # doorkeeper_token
        token.scopes
      elsif token.is_a?(Hash)
        token[:scopes] || token["scopes"] || []
      else
        []
      end
    end

    def read_scope?
      @scopes.include?("scenarios:read")
    end

    def write_scope?
      @scopes.include?("scenarios:write")
    end

    def delete_scope?
      @scopes.include?("scenarios:delete")
    end

    def admin?
      @user&.admin?
    end

    # Everyone can read public saved scenarios.
    def allow_public_read
      can :read, SavedScenario, private: false
    end

    # Allow reading saved scenarios and collections if the token has the read scope.
    def allow_read
      if admin?
        # Admins with read scope can read all saved scenarios and collections.
        can :read, SavedScenario
        can :read, Collection
      else
        can :read, SavedScenario, id: viewer_saved_scenario_ids
        can :read, Collection, id: user_collection_ids
      end
    end

    # Allow creating and updating saved scenarios and collections if the token has the write scope.
    def allow_write
      can :create, SavedScenario
      can :create, Collection

      if admin?
        # Admins with write scope can update all saved scenarios and collections.
        can :update, SavedScenario
        can :update, Collection
      else
        can :update, SavedScenario, id: collaborator_saved_scenario_ids
        can :update, Collection, id: user_collection_ids
      end
    end

    # Allow destroying saved scenarios and collections if the token has the delete scope.
    def allow_delete
      if admin?
        can :destroy, SavedScenario
        can :destroy, Collection
      else
        can :destroy, SavedScenario, id: owner_saved_scenario_ids
        can :destroy, Collection, id: user_collection_ids
      end
    end

    # Helper methods to fetch associated IDs for SavedScenario based on the user's role.

    def viewer_saved_scenario_ids
      SavedScenarioUser.where(
        user_id: @user.id,
        role_id: User::Roles.index_of(:scenario_viewer)..
      ).pluck(:saved_scenario_id)
    end

    def collaborator_saved_scenario_ids
      SavedScenarioUser.where(
        user_id: @user.id,
        role_id: User::Roles.index_of(:scenario_collaborator)..
      ).pluck(:saved_scenario_id)
    end

    def owner_saved_scenario_ids
      SavedScenarioUser.where(
        user_id: @user.id,
        role_id: User::Roles.index_of(:scenario_owner)
      ).pluck(:saved_scenario_id)
    end

    # Helper method for fetching Collection IDs for the user.
    def user_collection_ids
      Collection.where(user_id: @user.id).pluck(:id)
    end
  end
end
