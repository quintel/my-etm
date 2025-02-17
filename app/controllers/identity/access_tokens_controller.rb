module Identity
  # Why do we have this?
  # On login an accesstoken is sent to the client
  # Refresh tokens can be retrieved from a HTTP POST to /oauth/token ,
  # it is the same endpoint as login, but this time we are using “refresh_token”
  # as the value for grant_type, and is sending the value of refresh token instead of login credentials.
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
