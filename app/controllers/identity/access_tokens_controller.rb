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

    def exchange
      authenticate_with_http_token do |token, _options|
        @provided_pat = token
      end || (return render_pat_error('Missing PAT'))

      @client = Doorkeeper::Application.find_by(uid: params[:client_id])
      return render_pat_error('Invalid client') unless @client

      scopes = @client.scopes

      oauth_token = Doorkeeper::AccessToken.find_by(token: @provided_pat)
      return render_pat_error('Invalid PAT') unless oauth_token

      pat = PersonalAccessToken.not_expired.find_by(oauth_access_token_id: oauth_token.id)
      return render_pat_error('Invalid or expired PAT') unless pat

      user = pat.user

      jwt = MyEtm::Auth.user_jwt(user, scopes: scopes, client_id: @client.uid)
      render json: { access_token: jwt, token_type: "Bearer", expires_in: 3600 }
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


    def render_pat_error(message)
      render json: {
        error: 'invalid_request',
        error_description: message
      }, status: :unauthorized
    end
  end
end
