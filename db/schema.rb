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

ActiveRecord::Schema[7.2].define(version: 2024_10_20_045257) do
  create_table "featured_scenario_users", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "user_id"
    t.index ["user_id"], name: "index_featured_scenario_users_on_user_id"
  end

  create_table "featured_scenarios", charset: "utf8mb4", collation: "utf8mb4_0900_ai_ci", force: :cascade do |t|
    t.bigint "saved_scenario_id"
    t.bigint "featured_scenario_user_id"
    t.string "group"
    t.string "title_en", null: false
    t.string "title_nl", null: false
    t.text "description_en"
    t.text "description_nl"
    t.index ["featured_scenario_user_id"], name: "index_featured_scenarios_on_featured_scenario_user_id"
    t.index ["saved_scenario_id"], name: "index_featured_scenarios_on_saved_scenario_id"
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
    t.text "description"
    t.string "version", default: "latest"
    t.string "area_code", null: false
    t.integer "end_year", null: false
    t.boolean "private", default: false
    t.datetime "discarded_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["discarded_at"], name: "index_saved_scenarios_on_discarded_at"
    t.index ["scenario_id"], name: "index_saved_scenarios_on_scenario_id"
  end
end
