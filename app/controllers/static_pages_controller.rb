class StaticPagesController < ApplicationController
  before_action :require_feedback_email, only: [:send_message]

  # invisible_captcha(
  #   only: [:send_message],
  #   honeypot: :country,
  #   on_spam: :send_feedback_spam
  # )

  def empty

  end

  def contact
    @message = ContactUsMessage.new(
      name: current_user&.name || "",
      email: current_user&.email || "",
      message: ""
    )
  end

  def privacy
  end

  def terms
  end

  def send_message
    @message = ContactUsMessage.from_params(feedback_params)

    if @message.valid?
      ContactUsMailer.contact_email(
        @message,
        locale: I18n.locale,
        user_agent: request.env['HTTP_USER_AGENT']
      ).deliver

      flash[:notice] = t('contact.contact.success_flash')
      redirect_to contact_url
    else
      flash[:alert] = @message.errors.join(', ')
      redirect_to contact_url
    end
  end

  private

  def require_feedback_email
    redirect_to(contact_url) unless Settings.mailer.from
  end

  def feedback_params
    params.require(:contact_us_message).permit(:name, :email, :message)
  end

  def send_feedback_spam
    @message = ContactUsMessage.from_params(feedback_params)
    @message.valid?

    render :contact, status: :unprocessable_entity
  end
end
