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
      @subscribed = cast_subscription_param
      result = subscription_service.new.call(user: current_user, audience: @audience)

      if result.successful?
        handle_subscription_success
      else
        handle_subscription_failure(result.error)
      end
    end

    private

    # Converts the "subscribed" param to a boolean.
    def cast_subscription_param
      ActiveModel::Type::Boolean.new.cast(params[:subscribed])
    end

    # Chooses the correct service based on the subscription state.
    def subscription_service
      @subscribed ? CreateSubscription : DeleteSubscription
    end

    # Handles a successful subscription update.
    def handle_subscription_success
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            @audience.to_s,
            Identity::NewsletterStatusRowComponent.new(
              subscribed: @subscribed,
              audience: @audience
            ).render_in(view_context)
          )
        end
        format.html { redirect_to identity_profile_path, notice: "Subscription updated." }
      end
    end

    # Handles a failed subscription update.
    def handle_subscription_failure(error)
      Rails.logger.error("Subscription failed: #{error}")
      Sentry.capture_exception(error)
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.append(
            "flash-messages",
            partial: "shared/error",
            locals: { message: "Subscription update failed." }
          )
        end
        format.html { redirect_to identity_profile_path, alert: "Subscription update failed." }
      end
    end

    # Ensures Mailchimp is configured.
    def require_mailchimp_configured
      redirect_to(identity_profile_path) unless MyEtm::Mailchimp.enabled?
    end

    # Determines and validates the audience.
    def set_audience
      @audience = params[:audience]
      if @audience.is_a?(Hash)
        @audience = @audience[:audience] || @audience["audience"]
      end
      @audience = @audience&.to_sym
      unless %i[newsletter changelog].include?(@audience)
        redirect_to identity_profile_path, alert: "Invalid audience specified."
      end
    end
  end
end
