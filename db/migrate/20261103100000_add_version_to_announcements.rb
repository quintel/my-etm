class AddVersionToAnnouncements < ActiveRecord::Migration[8.1]
  def up
    # Announcements belong to a version from now on. The existing one is not kept.
    Announcement.delete_all

    add_reference(:announcements, :version, null: false, foreign_key: true, index: { unique: true })
  end

  def down
    remove_reference(:announcements, :version, foreign_key: true, index: { unique: true })
  end
end
