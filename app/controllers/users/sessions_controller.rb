# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    include JwtSessionCookies
    include EtmAppRedirects

    # Other ETM apps link here with the page the user was trying to reach. Devise resumes from
    # session["user_return_to"] after a successful sign-in, so stash it there; the POST that
    # follows no longer carries the query string.
    def new
      if (target = validated_etm_url(params[:return_to]))
        session["user_return_to"] = target
      end

      super
    end

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

        # Sent here from another ETM app: return the user to the page they were trying to reach
        # rather than to MyETM's home page. Rails refuses cross-host redirects unless the host is
        # declared expected; #new origin-checked this URL, which is what makes that safe. Only
        # consume the stored location when it is one of ours, so Devise still handles its own
        # relative paths (notably /oauth/authorize) normally.
        if (target = validated_etm_url(session["user_return_to"]))
          session.delete("user_return_to")
          return redirect_to(target, allow_other_host: true)
        end
      end
    end

    def destroy
      # current_user won't be available in the block as the sign out has already happened, so
      # capture what we need first.
      return_app = access_token&.application

      # Single logout: the access cookie is set on the parent domain, so clearing it signs the user
      # out of every ETM app in this browser within this one response. Revoking the anchor token
      # stops the session being slid again afterwards.
      revoke_jwt_session
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

    # Same reason as #require_no_authentication: Devise's verify_signed_out_user asks Warden whether
    # anyone is signed in, and with no Warden session the answer is always "nobody" — which would
    # short-circuit every sign-out with an "already signed out" response, before #destroy gets to
    # revoke the anchor token or clear the cookies. The JWT cookie is what being signed in means.
    def all_signed_out?
      current_user.blank?
    end

    def access_token
      @access_token ||= if params[:access_token].present? && current_user
        current_user.access_tokens.find_by(token: params[:access_token])
      end
    end

    # Returns a safe post-logout redirect target, falling back to the app that initiated the logout.
    def validated_post_logout_uri(return_app)
      validated_etm_url(params[:post_logout_redirect_uri]) || return_app.uri
    end

    def after_sign_out_path_for(...)
      Settings.etmodel_uri.presence || super
    end

    # Overridden only to allow the cross-host redirect. The keyword is Devise's: it responds :no_content
    # after a real sign-out and :unauthorized when the user was already signed out — pass it through.
    def respond_to_on_destroy(non_navigational_status: :no_content)
      respond_to do |format|
        format.all { head non_navigational_status }
        format.any(*navigational_formats) do
          redirect_to after_sign_out_path_for(resource_name), allow_other_host: true
        end
      end
    end
  end
end
