class AddFieldsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :deleted_at, :datetime
    add_column :users, :phone_number, :string
    add_column :users, :avatar_url, :string
    add_column :users, :bio, :text
    add_column :users, :role, :integer
    add_column :users, :confirmation_token, :string
    add_column :users, :confirmed_at, :datetime
    add_column :users, :confirmation_sent_at, :datetime
    add_index :users, :confirmation_token, unique: true
  end
end
