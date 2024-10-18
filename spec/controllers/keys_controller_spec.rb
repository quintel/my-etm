require 'rails_helper'
require 'myetm/auth'


RSpec.describe KeysController, type: :controller do
  describe 'GET #show' do
    let(:mocked_key) { OpenSSL::PKey::RSA.new(2048) }
    let(:mocked_jwk) { JSON::JWK.new(mocked_key.public_key) }

    context 'when the signing key is present' do
      before do
        allow(MyEtm::Auth).to receive(:signing_key).and_return(mocked_key)
      end

      it 'returns a successful response' do
        get :show

        expect(response).to have_http_status(:success)
      end

      it 'returns the JWK in the correct format' do
        get :show

        expected_response = {
          keys: [mocked_jwk]
        }.to_json

        expect(response.body).to eq(expected_response)
        expect(response.content_type).to eq('application/json; charset=utf-8')
      end
    end

    context 'when there is an error retrieving the signing key' do
      before do
        allow(MyEtm::Auth).to receive(:signing_key).and_raise(OpenSSL::PKey::RSAError, 'Signing key not available')
      end

      it 'returns a 500 Internal Server Error' do
        get :show

        expect(response).to have_http_status(:internal_server_error)
        expect(response.body).to include('Signing key not available')
      end
    end
  end
end
