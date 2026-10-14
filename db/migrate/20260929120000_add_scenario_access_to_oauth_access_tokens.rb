class AddScenarioAccessToOAuthAccessTokens < ActiveRecord::Migration[8.1]
  def change
    add_column(:oauth_access_tokens, :scenario_access, :json)
  end
end
