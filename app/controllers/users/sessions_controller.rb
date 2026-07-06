# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    include JwtSessionCookies

    def create
      # Devise yields the just-signed-in resource here; use it directly
      super do |resource|
        start_jwt_session(resource)
        # The etm_session JWT cookie is now the session of record. Drop the Warden session Devise
        # just persisted so the two can never drift: a stale Warden session outliving the JWT is
        # what bounced the user between sign_in and /oauth/authorize forever.
        sign_out(resource_name)
        if session["user_return_to"].to_s.start_with?("/oauth/authorize") && is_flashing_format?
          # Don't show the flash message when redirecting to an OAuth action.
          flash.delete(:notice)
        end
      end
    end

    def destroy
      # current_user won't be available in the block as the sign out has already happened, so
      # capture what we need first.
      user       = current_user
      return_app = access_token&.application

      # Single logout: revoke every one of the user's tokens/grants across all client apps, so the
      # short access-token TTL bounds how long any other app stays logged in.
      RevokeUserSessions.call(user) if user
      clear_jwt_session_cookies

      super do
        # Turbo requires redirects be :see_other (303); so override Devise default (302)
        target = return_app ? validated_post_logout_uri(return_app) : after_sign_out_path_for(resource_name)
        flash.delete(:notice) if return_app && is_flashing_format?
        return redirect_to(target, status: :see_other, allow_other_host: true)
      end
    end

    private

    # Devise's stock guard checks Warden, which we no longer persist. Base "already signed in" on
    # the JWT cookie (current_user) instead, so a valid session skips the form and a lapsed one
    # always shows it — the same source of truth Doorkeeper uses, so the two cannot loop.
    def require_no_authentication
      redirect_to(after_sign_in_path_for(current_user)) if current_user
    end

    def access_token
      @access_token ||= if params[:access_token].present? && current_user
        current_user.access_tokens.find_by(token: params[:access_token])
      end
    end

    # Returns a safe post-logout redirect target.
    def validated_post_logout_uri(return_app)
      requested = params[:post_logout_redirect_uri].presence
      return requested if requested && OAuthApplication.exists?(uri: requested)

      return_app.uri
    end

    def after_sign_out_path_for(...)
      Settings.etmodel_uri.presence || super
    end

    def respond_to_on_destroy
      respond_to do |format|
        format.all { head :no_content }
        format.any(*navigational_formats) do
          redirect_to after_sign_out_path_for(resource_name), allow_other_host: true
        end
      end
    end
  end
end
