class AddTmpDescriptionToSavedScenarios < ActiveRecord::Migration[7.2]
  def change
    add_column :saved_scenarios, :tmp_description, :text
  end
end
