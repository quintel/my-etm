# app/controllers/token_exchange_controller.rb
module Identity
  class TokenExchangeController < ApplicationController
    before_action :validate_bearer_token

    def create
      user = User.find_by(id: @user_id_from_bearer_token)
      if user
        jwt_token = MyEtm::Auth.user_jwt(user, scopes: extract_scopes_from_request, client_uri: client_uri)
        render json: { jwt: jwt_token }, status: :ok
      else
        render json: { error: 'Invalid user' }, status: :unauthorized
      end
    end

    private

    # Decode and validate the Bearer token
    def validate_bearer_token
      bearer_token = request.headers['Authorization']&.split(' ')&.last
      return render json: { error: 'Bearer token missing' }, status: :unauthorized unless bearer_token

      begin
        decoded_token = decode_bearer_token(bearer_token)
        @user_id_from_bearer_token = decoded_token[:sub] # Assuming `sub` holds the user ID
      rescue JWT::DecodeError => e
        render json: { error: 'Invalid bearer token' }, status: :unauthorized
      end
    end

    # Decode the Bearer token issued by the IdP
    def decode_bearer_token(bearer_token)
      key = MyEtm::Auth.signing_key
      decoded_token, _header = JWT.decode(bearer_token, key, true, { algorithm: 'RS256' })
      decoded_token.symbolize_keys
    end

    def extract_scopes_from_request
      params[:scopes] || []
    end

    def client_uri
      request.headers['Client-Uri']
    end
  end
end
