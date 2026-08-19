# frozen_string_literal: true

# Resolves a submitted item to an existing SavedScenarioUser. Expects a `saved_scenario` reader.
module SavedScenarioUserLookup
  private

  def find_saved_scenario_user(user_params)
    if user_params[:id]
      members.find_by(id: user_params[:id])
    elsif user_params[:user_id]
      members.find_by(user_id: user_params[:user_id])
    elsif user_params[:user_email]
      find_member_by_email(user_params[:user_email])
    end
  end

  def extract_identifier(user_params)
    user_params[:id] || user_params[:user_id] || user_params[:user_email]
  end

  # Coupling to a User clears user_email, so the reported address only resolves through the user.
  def find_member_by_email(email)
    members.find_by(user_email: email) || members.joins(:user).find_by(users: { email: email })
  end

  def members
    saved_scenario.saved_scenario_users
  end
end
