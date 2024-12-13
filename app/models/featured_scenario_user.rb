class FeaturedScenarioUser < ApplicationRecord
  belongs_to :user
  has_many :featured_scenarios, foreign_key: :owner_id, dependent: :destroy

  validates :name, presence: true
  validates :user, presence: true
end
