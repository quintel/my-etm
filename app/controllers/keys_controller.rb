class KeysController < ApplicationController
  def show
    key = MyEtm::Auth.signing_key
    jwk = JSON::JWK.new(key.public_key)

    render json: { keys: [jwk] }
  rescue OpenSSL::PKey::RSAError => e
    render json: { error: e.message }, status: :internal_server_error
  end
end
