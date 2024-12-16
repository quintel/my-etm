class FeaturedScenarioUser < ApplicationRecord
  # TODO user should be optional. Either User or Name.
  # TODO form to create Featured scenario users from admin console!
  belongs_to :user
  has_many :featured_scenarios, foreign_key: :owner_id, dependent: :destroy

  validates :name, presence: true
  validates :user, presence: true
end
