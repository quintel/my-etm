class DeviseCreateUsers < ActiveRecord::Migration[7.2]
  def change
    unless table_exists?(:users)
      create_table :users do |t|
        ## Database authenticatable
        t.string :email,              null: false, default: ""
        t.string :encrypted_password, null: false, default: ""

        ## Recoverable
        t.string   :reset_password_token
        t.datetime :reset_password_sent_at

        ## Rememberable
        t.datetime :remember_created_at

        ## Custom Fields
        t.string :name, null: false
        t.string :legacy_password_salt

        t.timestamps null: false
      end

      add_index :users, :email,                unique: true
      add_index :users, :reset_password_token, unique: true
    else
      # If the table exists, just add new columns as needed
      add_column :users, :name, :string unless column_exists?(:users, :name)
      add_column :users, :legacy_password_salt, :string unless column_exists?(:users, :legacy_password_salt)
    end
  end
end
