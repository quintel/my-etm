class CreateAnnouncements < ActiveRecord::Migration[8.1]
  def change
    create_table :announcements do |t|
      t.boolean :active, null: false, default: false
      t.text :body_en
      t.text :body_nl

      t.timestamps
    end
  end
end
