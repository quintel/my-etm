class User < ApplicationRecord
  enum :role, {:scenario_viewer=>1, :scenario_collaborator=>2, :scenario_owner=>3, :admin=>4}

  # Include necessary Devise modules
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :confirmable

  # Doorkeeper associations for handling OAuth2
  has_many :access_grants,
    class_name: 'Doorkeeper::AccessGrant',
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  has_many :access_tokens,
    class_name: 'Doorkeeper::AccessToken',
    foreign_key: :resource_owner_id,
    dependent: :delete_all

  # Add any relationships for OAuth2 applications
  has_many :oauth_applications,
    class_name: 'OAuthApplication',
    dependent: :delete_all,
    as: :owner

  validates :name, presence: true, length: { maximum: 191 }

  # Fallback password method for legacy support (if needed)
  def valid_password?(password)
    return true if super
    return super("#{password}#{legacy_password_salt}") if legacy_password_salt.present?
    false
  end

  # Roles handling
  def roles
    [role]
  end

  # JSON representation, excluding sensitive data
  def as_json(options = {})
    super(options.merge(except: Array(options[:except]) + [:legacy_password_salt]))
  end

  # User authentication status check
  def active_for_authentication?
    super && deleted_at.nil?
  end
end
