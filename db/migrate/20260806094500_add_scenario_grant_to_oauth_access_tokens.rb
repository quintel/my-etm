# frozen_string_literal: true

# Carries the ScenarioGrant on an access token, so a session that slides mid-edit keeps the access
# it was opened with. Surfaced into the JWT by doorkeeper_jwt.rb.
class AddScenarioGrantToOAuthAccessTokens < ActiveRecord::Migration[7.2]
  def change
    add_column :oauth_access_tokens, :scenario_grant_scenario_id, :bigint
    add_column :oauth_access_tokens, :scenario_grant_level, :string
  end
end
