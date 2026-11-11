class AddReleasedOnToVersions < ActiveRecord::Migration[8.1]
  def change
    add_column(:versions, :released_on, :date)
  end
end
