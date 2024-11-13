class CreateSavedScenarioUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :saved_scenario_users do |t|
      t.integer :saved_scenario_id, null: false
      t.integer :role_id, null: false
      t.integer :user_id, default: nil
      t.string  :user_email, default: nil, index: true
    end

    add_index :saved_scenario_users, [:saved_scenario_id, :user_id, :role_id]

    # Indices to put unique constraints a scenario for a given user_id/email
    # to prevent duplicate records and roles
    add_index :saved_scenario_users, [:saved_scenario_id, :user_id], unique: true
    add_index :saved_scenario_users, [:saved_scenario_id, :user_email], unique: true

  end
end
