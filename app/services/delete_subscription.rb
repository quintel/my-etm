class DeleteSubscription
  def call(user:, audience:)
    MyEtm::Mailchimp.unsubscribe(user.email, audience)
    Success.new
  rescue StandardError => e
    Failure.new(e)
  end
end
