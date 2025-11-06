class AddIdToCollectionSavedScenarios < ActiveRecord::Migration[7.2]
  def up
    # Drop any existing composite primary key (collection_id, saved_scenario_id)
    execute <<~SQL
      ALTER TABLE collection_saved_scenarios DROP PRIMARY KEY
    SQL

    # Add new auto-incrementing `id` primary key.
    add_column :collection_saved_scenarios, :id, :primary_key
  end

  def down
    remove_column :collection_saved_scenarios, :id

    # Restore the original composite primary key on rollback.
    execute <<~SQL
      ALTER TABLE collection_saved_scenarios ADD PRIMARY KEY (collection_id, saved_scenario_id)
    SQL
  end
end
