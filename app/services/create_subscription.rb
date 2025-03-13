class CreateSubscription
  include Service

  def call(user:, audience:)
    MyEtm::Mailchimp.subscribe(user.email, audience, merge_fields: user_mailchimp_data(user))
    ServiceResult.success
  rescue StandardError => e
    ServiceResult.failure(e)
  end

  private

  def user_mailchimp_data(user)
    first_name, *last_name = user.name.to_s.split(" ", 2)
    {
      FNAME: first_name.presence || "Unknown",
      LNAME: last_name.join(" ").presence || ""
    }
  end
end
