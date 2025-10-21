class AddUpdatedAtToCollections < ActiveRecord::Migration[7.2]
  def change
    add_column :collections, :updated_at, :datetime, null: true

    reversible do |dir|
      dir.up do
        execute <<~SQL.squish
          UPDATE collections
          SET updated_at = created_at
          WHERE updated_at IS NULL
        SQL
        change_column_null :collections, :updated_at, false
      end
    end
  end
end
