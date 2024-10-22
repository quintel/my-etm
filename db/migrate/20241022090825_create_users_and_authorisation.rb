class CreateUsersAndAuthorisation < ActiveRecord::Migration[7.2]
  def change
    # Modify the users table if it already exists
    if table_exists?(:users)
      change_table :users, bulk: true do |t|
        # Add columns only if they don't already exist
        t.string :encrypted_password, null: false, default: "" unless column_exists?(:users, :encrypted_password)
        t.string :reset_password_token unless column_exists?(:users, :reset_password_token)
        t.datetime :reset_password_sent_at unless column_exists?(:users, :reset_password_sent_at)
        t.datetime :remember_created_at unless column_exists?(:users, :remember_created_at)
        t.integer :sign_in_count, default: 0, null: false unless column_exists?(:users, :sign_in_count)
        t.datetime :current_sign_in_at unless column_exists?(:users, :current_sign_in_at)
        t.datetime :last_sign_in_at unless column_exists?(:users, :last_sign_in_at)
        t.string :current_sign_in_ip unless column_exists?(:users, :current_sign_in_ip)
        t.string :last_sign_in_ip unless column_exists?(:users, :last_sign_in_ip)
        t.string :confirmation_token unless column_exists?(:users, :confirmation_token)
        t.datetime :confirmed_at unless column_exists?(:users, :confirmed_at)
        t.datetime :confirmation_sent_at unless column_exists?(:users, :confirmation_sent_at)
        t.string :unconfirmed_email unless column_exists?(:users, :unconfirmed_email)
        t.datetime :deleted_at unless column_exists?(:users, :deleted_at)
        t.string :legacy_password_salt unless column_exists?(:users, :legacy_password_salt)
        t.string :name, null: false, default: "" unless column_exists?(:users, :name)
        t.boolean :private_scenarios, default: false unless column_exists?(:users, :private_scenarios)
        t.boolean :admin, null: false, default: false unless column_exists?(:users, :admin)

        # Add indexes only if they don't already exist
        t.index :email, unique: true unless index_exists?(:users, :email, unique: true)
        t.index :reset_password_token, unique: true unless index_exists?(:users, :reset_password_token, unique: true)
        t.index :confirmation_token, unique: true unless index_exists?(:users, :confirmation_token, unique: true)
      end
    else
      # If users table doesn't exist, create it
      create_table :users, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
        t.string :email, null: false, default: ""
        t.string :encrypted_password, null: false, default: ""
        t.string :reset_password_token
        t.datetime :reset_password_sent_at
        t.datetime :remember_created_at
        t.integer :sign_in_count, default: 0, null: false
        t.datetime :current_sign_in_at
        t.datetime :last_sign_in_at
        t.string :current_sign_in_ip
        t.string :last_sign_in_ip
        t.string :confirmation_token
        t.datetime :confirmed_at
        t.datetime :confirmation_sent_at
        t.string :unconfirmed_email
        t.datetime :deleted_at
        t.string :legacy_password_salt
        t.string :name, null: false, default: ""
        t.boolean :private_scenarios, default: false
        t.boolean :admin, null: false, default: false

        t.index :email, unique: true
        t.index :reset_password_token, unique: true
        t.index :confirmation_token, unique: true
      end
    end

    # Add foreign keys for Doorkeeper
    add_foreign_key :oauth_access_grants, :users, column: :resource_owner_id unless foreign_key_exists?(:oauth_access_grants, :users, column: :resource_owner_id)
    add_foreign_key :oauth_access_tokens, :users, column: :resource_owner_id unless foreign_key_exists?(:oauth_access_tokens, :users, column: :resource_owner_id)

    # Create staff_applications table
    create_table :staff_applications, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
      t.string :name, null: false
      t.bigint :user_id, null: false
      t.bigint :application_id, null: false

      t.index ["application_id"], name: "fk_rails_6768c0af4c"
      t.index ["user_id", "name"], name: "index_staff_applications_on_user_id_and_name", unique: true
      t.index ["user_id"], name: "index_staff_applications_on_user_id"
    end

    add_foreign_key :staff_applications, :oauth_applications, column: :application_id
    add_foreign_key :staff_applications, :users

    # Create oauth_openid_requests table
    create_table :oauth_openid_requests, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
      t.bigint :access_grant_id, null: false
      t.string :nonce, null: false

      t.index ["access_grant_id"], name: "index_oauth_openid_requests_on_access_grant_id"
    end

    add_foreign_key :oauth_openid_requests, :oauth_access_grants, column: :access_grant_id, on_delete: :cascade

    # Create personal_access_tokens table
    create_table :personal_access_tokens, charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
      t.bigint :user_id, null: false
      t.bigint :oauth_access_token_id, null: false
      t.string :name
      t.datetime :last_used_at

      t.index ["oauth_access_token_id"], name: "index_personal_access_tokens_on_oauth_access_token_id", unique: true
      t.index ["user_id"], name: "index_personal_access_tokens_on_user_id"
    end

    add_foreign_key :personal_access_tokens, :users
    add_foreign_key :personal_access_tokens, :oauth_access_tokens, column: :oauth_access_token_id

    # Add foreign keys for oauth grants and tokens
    add_foreign_key :oauth_access_grants, :oauth_applications, column: :application_id unless foreign_key_exists?(:oauth_access_grants, :oauth_applications, column: :application_id)
    add_foreign_key :oauth_access_tokens, :oauth_applications, column: :application_id unless foreign_key_exists?(:oauth_access_tokens, :oauth_applications, column: :application_id)
  end
end
