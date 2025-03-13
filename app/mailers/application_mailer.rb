class ApplicationMailer < ActionMailer::Base
  helper(EmailHelper)

  default from: "from@example.com"
  layout "mailer"
end
