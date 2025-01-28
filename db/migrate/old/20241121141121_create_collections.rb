class CreateCollections < ActiveRecord::Migration[7.2]
  def change
    # Create collections table
    create_table :collections, charset: "utf8mb4", collation: "utf8mb4_unicode_ci" do |t|
      t.bigint :user_id, null: false
      t.string :title, null: false
      t.string :area_code
      t.integer :end_year
      t.string :version, default: 'latest'
      t.datetime :created_at, null: false
      t.datetime :discarded_at
      t.boolean :interpolation, default: true

      t.index :discarded_at, name: "index_collections_on_discarded_at"
      t.index :user_id, name: "index_collections_on_user_id"
    end

    # Add foreign key for collections -> users
    add_foreign_key :collections, :users

    # Create collection_saved_scenarios table
    create_table :collection_saved_scenarios, primary_key: [:collection_id, :saved_scenario_id], charset: "utf8mb3" do |t|
      t.bigint :collection_id, null: false
      t.bigint :saved_scenario_id, null: false

      t.index :collection_id, name: "index_collection_saved_scenarios_on_collection_id"
      t.index :saved_scenario_id, name: "index_collection_saved_scenarios_on_saved_scenario_id"
    end

    # Create collection_scenarios table
    create_table :collection_scenarios, charset: "utf8mb4", collation: "utf8mb4_unicode_ci" do |t|
      t.bigint :collection_id, null: false
      t.integer :scenario_id, null: false

      t.index :collection_id, name: "index_collection_scenarios_on_collection_id"
      t.index :scenario_id, name: "index_collection_scenarios_on_scenario_id"
    end

    # Add foreign keys for related tables
    add_foreign_key :collection_saved_scenarios, :collections
    add_foreign_key :collection_saved_scenarios, :saved_scenarios
    add_foreign_key :collection_scenarios, :collections
  end
end
