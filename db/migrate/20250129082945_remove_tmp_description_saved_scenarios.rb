class RemoveTmpDescriptionSavedScenarios < ActiveRecord::Migration[7.2]
  def change
    remove_column :saved_scenarios, :tmp_description, :text
  end
end
