class DeviseCustomMailer < Devise::Mailer
  helper(EmailHelper)

  # Override to deliver all Devise emails asynchronously via Sidekiq
  def self.deliver_later(email, options = {})
    # Use high-priority mailers queue for fast delivery
    super(email, options.merge(queue: :mailers))
  end
end
