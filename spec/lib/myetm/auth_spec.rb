require 'rails_helper'
require 'openssl'
require 'myetm/auth'
require 'jwt'

RSpec.describe MyEtm::Auth do
  let(:user) { double('User', id: 1, name: 'Test User') }
  let(:predefined_key) { OpenSSL::PKey::RSA.new(2048) }
  let(:key_path) { Rails.root.join('tmp/jwt_signing_key.pem') }

  describe 'user_jwt' do
    it 'creates a valid JWT for a user' do
      token = MyEtm::Auth.user_jwt(user)
      decoded_token = JWT.decode(token, MyEtm::Auth.signing_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first['sub']).to eq(user.id)
      expect(decoded_token.first['iss']).to eq('myetm-idp')
      expect(decoded_token.first['aud']).to eq('client-id')
      expect(decoded_token.first['user']['name']).to eq('Test User')
    end

    it 'includes the scopes in the JWT' do
      scopes = ['read', 'write']
      token = MyEtm::Auth.user_jwt(user, scopes: scopes)
      decoded_token = JWT.decode(token, MyEtm::Auth.signing_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first['scopes']).to eq(scopes)
    end

    it 'expires the token in 2 hours' do
      token = MyEtm::Auth.user_jwt(user)
      decoded_token = JWT.decode(token, MyEtm::Auth.signing_key.public_key, true, { algorithm: 'RS256' })

      expect(decoded_token.first['exp']).to be_within(5).of(2.hours.from_now.to_i)
    end
  end

  describe 'signing_key_content' do
    context 'when JWT_SIGNING_KEY env variable is set' do
      before { ENV['JWT_SIGNING_KEY'] = predefined_key.to_pem }

      it 'returns the key from the environment variable' do
        expect(MyEtm::Auth.signing_key_content).to eq(ENV['JWT_SIGNING_KEY'])
      end
    end

    context 'when no key is present' do
      before do
        ENV['JWT_SIGNING_KEY'] = nil
        File.delete(key_path) if key_path.exist?
        allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new('production'))
      end

      it 'raises an error if no signing key is available' do
        expect { MyEtm::Auth.signing_key_content }.to raise_error('No signing key is present. Please set JWT_SIGNING_KEY or provide a key at tmp/jwt_signing_key.pem')
      end
    end
  end
end
