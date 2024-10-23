class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable and :omniauthable, :registerable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :confirmable, :trackable

  # rubocop:disable Rails/InverseOf
  has_many :access_grants,
    class_name: 'Doorkeeper::AccessGrant',
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  has_many :access_tokens,
    class_name: 'Doorkeeper::AccessToken',
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  has_many :oauth_applications,
    class_name: 'OAuthApplication',
    dependent: :delete_all,
    as: :owner

  has_many :staff_applications, dependent: :destroy
  has_many :scenario_users, dependent: :destroy
  has_many :scenarios, through: :scenario_users
  has_many :scenario_version_tags
  has_many :personal_access_tokens, dependent: :destroy

  validates :name, presence: true, length: { maximum: 191 }

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

  def as_json(options = {})
    super(options.merge(except: Array(options[:except])))
  end
end
