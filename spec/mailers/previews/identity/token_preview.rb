# Preview all emails at http://localhost:3002/rails/mailers/identity/token
class Identity::TokenPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3002/rails/mailers/identity/token/created_token
  def created_token
    Identity::TokenMailer.created_token(personal_access_token)
  end

  def expiring_token
    Identity::TokenMailer.expiring_token(personal_access_token)
  end

  private

  def personal_access_token
    FactoryBot.create(:personal_access_token, user: User.all.first)
  end
end
