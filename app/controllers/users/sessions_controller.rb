# frozen_string_literal: true

module Users
  class SessionsController < Devise::SessionsController
    def create
      super do
        if session["user_return_to"].to_s.start_with?("/oauth/authorize") && is_flashing_format?
          # Don't show the flash message when redirecting to an OAuth action.
          flash.delete(:notice)
        end
      end
    end

    def destroy
      # current_user won't be available in the block as the sign out has already happened.
      token = access_token

      super do
        if token
          token.revoke if token.accessible?

          # Don't set a flash when redirecting back to a client application.
          if token.application
            flash.delete(:notice) if is_flashing_format?
            return redirect_to(token.application.uri, allow_other_host: true)
          end
        end

        # Turbo requires redirects be :see_other (303); so override Devise default (302)
        return redirect_to(
          after_sign_out_path_for(resource_name),
          status: :see_other, allow_other_host: true
        )
      end
    end

    private

    def access_token
      @access_token ||= if params[:access_token].present? && current_user
        current_user.access_tokens.find_by(token: params[:access_token])
      end
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
