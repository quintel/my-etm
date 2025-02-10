# frozen_string_literal: true

module Identity
  class NewsletterController < ApplicationController
    include IdentityController

    before_action :require_mailchimp_configured
    before_action :set_audience

    def edit
      redirect_to(identity_profile_path) unless turbo_frame_request?
    end

    def update
      @subscribed = ActiveModel::Type::Boolean.new.cast(params[:subscribed])
      service = @subscribed ? CreateSubscription : DeleteSubscription

      result = service.new.call(user: current_user, audience: @audience)

      if result.successful?
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.replace(@audience.to_s, partial: "identity/newsletter_status_row", locals: { audience: @audience }) }
          format.html { redirect_to identity_profile_path, notice: "Subscription updated." }
        end
      else
        Rails.logger.error "Subscription failed: #{result.error}"
        Sentry.capture_exception(result.error)
        respond_to do |format|
          format.turbo_stream { render turbo_stream: turbo_stream.append("flash-messages", partial: "shared/error", locals: { message: "Subscription update failed." }) }
          format.html { redirect_to identity_profile_path, alert: "Subscription update failed." }
        end
      end
    end

    private

    # Ensure Mailchimp is configured for the selected audience
    def require_mailchimp_configured
      redirect_to(identity_profile_path) unless MyEtm::Mailchimp.enabled?
    end

    # Determine which audience is being handled
    def set_audience
      @audience = params[:audience]

      if @audience.is_a?(Hash)
        @audience = @audience[:audience] || @audience['audience']
      end

      @audience = @audience&.to_sym

      unless %i[newsletter changelog].include?(@audience)
        redirect_to identity_profile_path, alert: "Invalid audience specified."
      end
    end
  end
end
