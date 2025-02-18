class FeaturedScenarioUser < ApplicationRecord
  belongs_to :user
  has_many :featured_scenarios, foreign_key: :owner_id, dependent: :destroy

  validate :user_or_name_must_exist

  def user_name
    name.presence || user.name
  end

  def user_or_name_must_exist
    if user.blank? && name.blank?
      errors.add(:base, "Either user or name must be present")
    end
  end
end
