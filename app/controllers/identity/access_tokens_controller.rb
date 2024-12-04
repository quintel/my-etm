module Identity
  class AccessTokensController < ApplicationController
    skip_before_action :verify_authenticity_token

    def create
      @client = Doorkeeper::Application.find_by(uid: params[:client_id])
      @user = User.find_by(id: params[:user_id])

      # Validate client credentials
      if valid_client?
        token = generate_access_token
        render json: { access_token: token, token_type: "Bearer", expires_in: 3600 }
      else
        render json: { error: "invalid_client" }, status: :unauthorized
      end
    end

    private

    def valid_client?
      return false unless @client
      true
    end

    def generate_access_token
      scopes = @client.scopes
      MyEtm::Auth.user_jwt(@user, scopes: scopes, client_id: @client.uid)
    end
  end
end
