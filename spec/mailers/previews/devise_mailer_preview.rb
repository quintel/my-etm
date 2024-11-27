class DeviseMailerPreview < ActionMailer::Preview
  def reset_password_instructions
    user = User.first || User.new(email: 'test@example.com') # Adjust based on your model
    token = "dummy_reset_token"
    Devise::Mailer.reset_password_instructions(user, token)
  end
end
