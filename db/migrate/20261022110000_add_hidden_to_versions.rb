class AddHiddenToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column(:versions, :hidden, :boolean, default: false, null: false)
  end
end
