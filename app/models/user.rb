class User < ApplicationRecord
  ROLES = {
    1 => :scenario_viewer,
    2 => :scenario_collaborator,
    3 => :scenario_owner
  }.freeze

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable, :registerable
  devise :database_authenticatable, :registerable,
    :recoverable, :rememberable, :validatable,
    :confirmable, :trackable

  # rubocop:disable Rails/InverseOf
  has_many :access_grants,
    class_name: "Doorkeeper::AccessGrant",
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  has_many :access_tokens,
    class_name: "Doorkeeper::AccessToken",
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  has_many :oauth_applications,
    class_name: "OAuthApplication",
    dependent: :delete_all,
    as: :owner

  has_many :staff_applications, dependent: :destroy
  has_many :saved_scenario_users, dependent: :destroy
  has_many :saved_scenarios, through: :saved_scenario_users
  has_many :collections, dependent: :destroy
  has_many :personal_access_tokens, dependent: :destroy

  has_one :featured_scenario_user

  validates :name, presence: true, length: { maximum: 191 }

  after_create :couple_saved_scenario_users

  def valid_password?(password)
    return true if super

    false
  end

  def roles
    admin? ? %w[user admin] : %w[user]
  end

  def active_for_authentication?
    super && deleted_at.nil?
  end

  def featured?
    featured_scenario_user.present?
  end

  def as_json(options = {})
    super(options.merge(except: Array(options[:except])))
  end

  def couple_saved_scenario_users
    SavedScenarioUser
      .where(user_email: email, user_id: nil)
      .update_all(user_id: id, user_email: nil)
  end

  # Finds or creates a user from a JWT token.
  def self.from_jwt!(token)
    id = token["sub"]
    raise "Token does not contain user information" unless id.present?
    User.find_or_create_by!(id: id)
  end
end
