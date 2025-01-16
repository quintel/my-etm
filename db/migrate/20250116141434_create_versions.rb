class CreateVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :versions do |t|
      t.string :tag, null: false
      t.string :url_prefix
      t.boolean :default, default: false
      t.timestamps
    end

    add_index :versions, :tag, unique: true

    add_reference :oauth_applications, :version, foreign_key: true
  end
end
