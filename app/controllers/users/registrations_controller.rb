# frozen_string_literal: true

module Users
  class RegistrationsController < Devise::RegistrationsController
    before_action :configure_sign_up_params, only: [ :create ]
    before_action :configure_account_update_params, only: [ :update ]

    def confirm_destroy
      @counts = stats_for_destroy
      render :confirm_destroy, layout: "application"
    end

    def destroy
      current_password = params.require(:user)[:current_password]

      unless resource.update_with_password(deleted_at: Time.now.utc, current_password:)
        confirm_destroy
        return
      end

      Devise.sign_out_all_scopes ? sign_out : sign_out(resource_name)

      Identity::DestroyUserJob.perform_later(@user.id)

      redirect_to(
        after_sign_out_path_for(resource_name),
        allow_other_host: true
      )
    end

    private

    def after_sign_out_path_for(...)
      redirect_to root_path
    end

    def update_resource(resource, params)
      if params.key?(:password) || params.key?(:email)
        super
      else
        resource.update_without_password(params)
      end
    end

    # If you have extra params to permit, append them to the sanitizer.
    def configure_sign_up_params
      devise_parameter_sanitizer.permit(:sign_up, keys: [ :name ])
    end

    # If you have extra params to permit, append them to the sanitizer.
    def configure_account_update_params
      devise_parameter_sanitizer.permit(:account_update, keys: [ :name ])
    end

    # Fetches information about what entities will be deleted with the account.
    def stats_for_destroy
      {
        saved_scenarios: current_user.saved_scenarios.count,
        personal_access_tokens: current_user.personal_access_tokens.not_expired.count,
        oauth_applications: current_user.oauth_applications.count,
        collections: current_user.collections.count
      }
    end
  end
end
