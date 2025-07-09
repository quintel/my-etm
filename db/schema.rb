# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.2].define(version: 2025_07_09_122138) do
  create_table "action_text_rich_texts", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.text "body", size: :long
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "collection_saved_scenarios", primary_key: ["collection_id", "saved_scenario_id"], charset: "utf8mb3", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.bigint "saved_scenario_id", null: false
    t.index ["collection_id"], name: "index_collection_saved_scenarios_on_collection_id"
    t.index ["saved_scenario_id"], name: "index_collection_saved_scenarios_on_saved_scenario_id"
  end

  create_table "collection_scenarios", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "collection_id", null: false
    t.integer "scenario_id", null: false
    t.index ["collection_id"], name: "index_collection_scenarios_on_collection_id"
    t.index ["scenario_id"], name: "index_collection_scenarios_on_scenario_id"
  end

  create_table "collections", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "title", null: false
    t.string "area_code"
    t.integer "end_year"
    t.datetime "created_at", null: false
    t.datetime "discarded_at"
    t.boolean "interpolation", default: true
    t.bigint "version_id"
    t.index ["discarded_at"], name: "index_collections_on_discarded_at"
    t.index ["user_id"], name: "index_collections_on_user_id"
    t.index ["version_id"], name: "index_collections_on_version_id"
  end

  create_table "featured_scenario_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_featured_scenario_users_on_user_id"
  end

  create_table "featured_scenarios", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "saved_scenario_id"
    t.bigint "owner_id"
    t.string "group"
    t.string "title_en", null: false
    t.string "title_nl", null: false
    t.index ["owner_id"], name: "index_featured_scenarios_on_owner_id"
    t.index ["saved_scenario_id"], name: "index_featured_scenarios_on_saved_scenario_id"
  end

  create_table "oauth_access_grants", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "resource_owner_id", null: false
    t.bigint "application_id", null: false
    t.string "token", null: false
    t.integer "expires_in", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.index ["application_id"], name: "index_oauth_access_grants_on_application_id"
    t.index ["resource_owner_id"], name: "index_oauth_access_grants_on_resource_owner_id"
    t.index ["token"], name: "index_oauth_access_grants_on_token", unique: true
  end

  create_table "oauth_access_tokens", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "resource_owner_id"
    t.bigint "application_id"
    t.text "token", null: false
    t.string "refresh_token"
    t.integer "expires_in"
    t.string "scopes"
    t.datetime "created_at", null: false
    t.datetime "revoked_at"
    t.string "previous_refresh_token", default: "", null: false
    t.index ["application_id"], name: "index_oauth_access_tokens_on_application_id"
    t.index ["refresh_token"], name: "index_oauth_access_tokens_on_refresh_token", unique: true
    t.index ["resource_owner_id"], name: "index_oauth_access_tokens_on_resource_owner_id"
  end

  create_table "oauth_applications", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.string "uid", null: false
    t.string "secret", null: false
    t.text "redirect_uri", null: false
    t.string "scopes", default: "", null: false
    t.boolean "confidential", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "uri", null: false
    t.integer "owner_id", null: false
    t.string "owner_type", null: false
    t.boolean "first_party", default: false, null: false
    t.bigint "version_id"
    t.index ["owner_id", "owner_type"], name: "index_oauth_applications_on_owner_id_and_owner_type"
    t.index ["uid"], name: "index_oauth_applications_on_uid", unique: true
    t.index ["version_id"], name: "index_oauth_applications_on_version_id"
  end

  create_table "oauth_openid_requests", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "access_grant_id", null: false
    t.string "nonce", null: false
    t.index ["access_grant_id"], name: "index_oauth_openid_requests_on_access_grant_id"
  end

  create_table "personal_access_tokens", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "oauth_access_token_id", null: false
    t.string "name"
    t.datetime "last_used_at"
    t.index ["oauth_access_token_id"], name: "index_personal_access_tokens_on_oauth_access_token_id", unique: true
    t.index ["user_id"], name: "index_personal_access_tokens_on_user_id"
  end

  create_table "saved_scenario_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "saved_scenario_id", null: false
    t.integer "role_id", null: false
    t.integer "user_id"
    t.string "user_email"
    t.index ["saved_scenario_id", "user_email"], name: "index_saved_scenario_users_on_saved_scenario_id_and_user_email", unique: true
    t.index ["saved_scenario_id", "user_id", "role_id"], name: "idx_on_saved_scenario_id_user_id_role_id_4259c2652e"
    t.index ["saved_scenario_id", "user_id"], name: "index_saved_scenario_users_on_saved_scenario_id_and_user_id", unique: true
    t.index ["user_email"], name: "index_saved_scenario_users_on_user_email"
  end

  create_table "saved_scenarios", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.integer "scenario_id", null: false
    t.text "scenario_id_history"
    t.string "title", null: false
    t.string "area_code", null: false
    t.integer "end_year", null: false
    t.boolean "private", default: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "version_id"
    t.index ["discarded_at"], name: "index_saved_scenarios_on_discarded_at"
    t.index ["scenario_id"], name: "index_saved_scenarios_on_scenario_id"
    t.index ["version_id"], name: "index_saved_scenarios_on_version_id"
  end

  create_table "sessions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["session_id"], name: "index_sessions_on_session_id", unique: true
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "staff_applications", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id", null: false
    t.bigint "application_id", null: false
    t.index ["application_id"], name: "fk_rails_6768c0af4c"
    t.index ["user_id", "name"], name: "index_staff_applications_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_staff_applications_on_user_id"
  end

  create_table "users", charset: "utf8mb4", collation: "utf8mb4_unicode_ci", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.integer "sign_in_count", default: 0, null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string "current_sign_in_ip"
    t.string "last_sign_in_ip"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.datetime "deleted_at"
    t.string "name", default: "", null: false
    t.boolean "private_scenarios", default: false
    t.boolean "admin", default: false, null: false
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "versions", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "tag", null: false
    t.string "url_prefix"
    t.boolean "default", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tag"], name: "index_versions_on_tag", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "collection_saved_scenarios", "collections"
  add_foreign_key "collection_saved_scenarios", "saved_scenarios"
  add_foreign_key "collection_scenarios", "collections"
  add_foreign_key "collections", "users"
  add_foreign_key "collections", "versions"
  add_foreign_key "oauth_access_grants", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_grants", "users", column: "resource_owner_id"
  add_foreign_key "oauth_access_tokens", "oauth_applications", column: "application_id"
  add_foreign_key "oauth_access_tokens", "users", column: "resource_owner_id"
  add_foreign_key "oauth_applications", "versions"
  add_foreign_key "oauth_openid_requests", "oauth_access_grants", column: "access_grant_id", on_delete: :cascade
  add_foreign_key "personal_access_tokens", "oauth_access_tokens"
  add_foreign_key "personal_access_tokens", "users"
  add_foreign_key "saved_scenarios", "versions"
  add_foreign_key "staff_applications", "oauth_applications", column: "application_id"
  add_foreign_key "staff_applications", "users"
end
