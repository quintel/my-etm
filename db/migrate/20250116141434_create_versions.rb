class CreateVersions < ActiveRecord::Migration[7.2]
  def change
    create_table :versions do |t|
      t.string :tag, null: false
      t.string :url_prefix
      t.boolean :default, default: false
      t.timestamps
    end

    add_index :versions, :tag, unique: true

    # Rename old versions
    rename_column :saved_scenarios, :version, :version_old
    rename_column :collections, :version, :version_old

    # Add foreign keys
    add_reference :oauth_applications, :version, foreign_key: true
    add_reference :saved_scenarios, :version, foreign_key: true
    add_reference :collections, :version, foreign_key: true

    # Migrate saved scenarios and collections to use db Versions
    default = Version.create!(default: true, tag: :latest)
    SavedScenario.where(version_old: 'latest').update_all(version_id: default.id)
    Collection.where(version_old: 'latest').update_all(version_id: default.id)

    stable1 = Version.create!(tag: 'stable.01', url_prefix: 'stable')
    SavedScenario.where(version_old: 'stable.01').update_all(version_id: stable1.id)
    Collection.where(version_old: 'stable.01').update_all(version_id: stable1.id)

    stable2 = Version.create!(tag: 'stable.02', url_prefix: 'stable2')
    SavedScenario.where(version_old: 'stable.02').update_all(version_id: stable2.id)
    Collection.where(version_old: 'stable.02').update_all(version_id: stable2.id)

    # Clean up
    remove_column(:saved_scenarios, :version_old)
    remove_column(:collections, :version_old)
  end
end
