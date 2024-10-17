class CreateSavedScenarios < ActiveRecord::Migration[7.2]
  def change
    create_table :saved_scenarios do |t|
      t.integer :scenario_id, index: true, null: false
      t.text :scenario_id_history
      t.string :title, null: false
      t.text :description
      t.string :version, default: 'latest'
      t.string :area_code, null: false
      t.integer :end_year, null: false
      t.boolean :private, default: false
      t.datetime :discarded_at, index: true

      t.timestamps
    end
  end
end
