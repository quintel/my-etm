class SavedScenarioUser < ApplicationRecord
  belongs_to :saved_scenario
  belongs_to :user, optional: true

  validate :user_id_or_email
  validates :user_email, format: { with: Devise.email_regexp }, if: :no_user_present?
  validates :role_id, inclusion: { in: User::Roles.all }


  # Always make sure one owner is left on the SavedScenario
  # this record is part of before changing its role or removing it.
  before_save :ensure_one_owner_left_before_save
  before_destroy :ensure_one_owner_left_before_destroy

  def as_json(*)
    params = super

    params[:role] = User::Roles.name_for(role_id)
    params.except(:role_id)
  end

  def initials
    user.present? ? user.name.first : user_email.first
  end

  def email
    user.present? ? user.email : user_email
  end

  def name
    user&.name
  end

  private

  def no_user_present?
    user_id.blank?
  end

  # Validation: Either user_id or user_email should be present, but not both
  def user_id_or_email
    return if user_id.blank? ^ user_email.blank?

    errors.add(
      :base,
      :user_or_email_blank,
      message: "Either user_id or user_email should be present."
    )
  end

  # Hook: Don't save when it leaves the scenario ownerles
  # Don't check new records and ignore if the role is set to owner.
  def ensure_one_owner_left_before_save
    return if new_record? || role_id == User::Roles.index_of(:scenario_owner)

    ensure_last_owner
  end

  # Hook: Don't remove this user when they were the last owner
  # If the saved_scenario or user is getting destroyed, skip this validation
  def ensure_one_owner_left_before_destroy
    return if destroyed_by_association
    return unless role_id == User::Roles.index_of(:scenario_owner)

    ensure_last_owner
  end

  # Private: Is this user the last owner
  def last_owner?
    saved_scenario
      .saved_scenario_users.where.not(id: id)
      .pluck(:role_id).compact.uniq
      .none?(User::Roles.index_of(:scenario_owner))
  end

  # Private: Aborts when this was the last owner of the scenario
  def ensure_last_owner
    return unless last_owner?

    errors.add(:base, :ownership, message: "Last owner cannot be altered")
    throw(:abort)
  end
end
