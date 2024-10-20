class CreateFeaturedScenarios < ActiveRecord::Migration[7.2]
  def change
    create_table :featured_scenarios do |t|
      t.belongs_to :saved_scenario
      t.belongs_to :featured_scenario_user
      t.string :group
      t.string :title_en, null: false
      t.string :title_nl, null: false
      t.text :description_en
      t.text :description_nl
    end
  end
end
