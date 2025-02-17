class ChangeAccesTokensFieldToText < ActiveRecord::Migration[7.2]
  def change
    remove_index :oauth_access_tokens, :token
    change_column :oauth_access_tokens, :token, :text, limit: 400
  end
end
