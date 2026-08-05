# frozen_string_literal: true

# A site-wide message shown in the ETM front-ends, such as a planned maintenance notice.
#
# One row is edited through the admin panel. The API serves a collection, so announcements can
# later be scoped to a single front-end or version without changing how consumers read them.
class Announcement < ApplicationRecord
  # The banner is a single line in the ETM, and longer messages are shortened with an ellipsis.
  MAX_LENGTH = 150

  scope :active, -> { where(active: true) }

  validates :body_en, presence: true, if: :active?
  validates :body_en, :body_nl, length: { maximum: MAX_LENGTH }

  # The row shown in the admin panel, created on the first visit.
  def self.editable
    first || create!
  end

  def as_json(*)
    { body_en:, body_nl: }
  end
end
