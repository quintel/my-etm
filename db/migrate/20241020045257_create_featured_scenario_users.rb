class CreateFeaturedScenarioUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :featured_scenario_users do |t|
      t.string :name, null: false
      t.belongs_to :user
    end
  end
end
