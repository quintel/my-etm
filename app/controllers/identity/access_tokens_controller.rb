module Identity
  class AccessTokensController < ApplicationController
    skip_before_action :verify_authenticity_token # Skip CSRF for API requests

    def create
      client_id = params[:client_id]
      client_secret = params[:client_secret]
      user_id = params[:user_id]

      # Validate client credentials
      if valid_client?(client_id, client_secret)
        # If a user is authenticated (e.g., via session or token), include them in the JWT
        user = current_user || User.find_by(id: user_id)

        token = generate_access_token(client_id, user)
        render json: { access_token: token, token_type: 'Bearer', expires_in: 3600 }
      else
        render json: { error: 'invalid_client' }, status: :unauthorized
      end
    end

    private

    def valid_client?(client_id, client_secret)
      # Find the OAuth application by client_id
      application = Doorkeeper::Application.find_by(uid: client_id)
      # Return false if the application does not exist or the secret does not match
      return false unless application
      return false unless ActiveSupport::SecurityUtils.secure_compare(application.secret, client_secret)

      true
    end

    def generate_access_token(client_id, user = nil)
      scopes = Doorkeeper::Application.find_by(uid: client_id).scopes
      MyEtm::Auth.user_jwt(user, scopes: scopes, client_id: client_id)
    end
  end
end
