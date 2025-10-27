class AddSavedScenarioOrderToCollectionSavedScenarios < ActiveRecord::Migration[7.2]
  def change
    add_column :collection_saved_scenarios, :saved_scenario_order, :integer, null: false, default: 0
  end
end
