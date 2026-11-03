# frozen_string_literal: true

# A message shown in the ETM front-ends of one version, such as a planned maintenance notice.
#
# Each version has at most one, edited through the admin panel. A front-end shows only its own
# version's, so the message is all there is to fit in the banner.
class Announcement < ApplicationRecord
  # The banner is a single line in the ETM, and longer messages are shortened with an ellipsis.
  MAX_LENGTH = 150

  belongs_to :version

  scope :active, -> { where(active: true) }

  validates :body_en, presence: true, if: :active?
  validates :body_en, :body_nl, length: { maximum: MAX_LENGTH }
  validates :version_id, uniqueness: true

  # The row shown in the admin panel for the version, created on the first visit.
  def self.editable(version)
    find_or_create_by!(version:)
  end

  def as_json(*)
    { body_en:, body_nl: }
  end
end
