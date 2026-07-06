# frozen_string_literal: true

RSpec.describe Users::SessionsController do
  let(:user) { create(:user) }

  let(:application) do
    OAuthApplication.create!(
      name: 'Test Application',
      uri: 'https://example.com',
      redirect_uri: 'https://example.com/auth/callback',
      owner: user,
      version: Version.default
    )
  end

  let(:token) do
    Doorkeeper::AccessToken.create!(
      application:,
      resource_owner_id: user.id
    )
  end

  before do
    Settings.etmodel_uri = 'http://etmodel.test'
    request.env['devise.mapping'] = Devise.mappings[:user]
  end

  after { Settings.reload! }

  context 'when signing out with an access token' do
    before { sign_in(user) }

    it 'redirects to the application URL' do
      delete :destroy, params: { access_token: token.token }
      expect(response).to redirect_to('https://example.com')
    end

    it 'revokes the token' do
      expect { delete(:destroy, params: { access_token: token.token }) }
        .to change { token.reload.revoked? }.from(false).to(true)
    end
  end

  context 'when signing out with no access token' do
    before { sign_in(user) }

    it 'redirects to ETModel' do
      delete :destroy
      expect(response).to redirect_to(Settings.etmodel_uri)
    end
  end

  context 'when signing out with an access token that does not exist' do
    before { sign_in(user) }

    it 'redirects to ETModel' do
      delete :destroy, params: { access_token: 'invalid' }
      expect(response).to redirect_to(Settings.etmodel_uri)
    end
  end

  context 'when the user has tokens for several applications' do
    let(:other_application) do
      OAuthApplication.create!(
        name: 'Other Application',
        uri: 'https://other.example.com',
        redirect_uri: 'https://other.example.com/auth/callback',
        owner: user,
        version: Version.default
      )
    end

    let(:other_token) do
      Doorkeeper::AccessToken.create!(application: other_application, resource_owner_id: user.id)
    end

    before { sign_in(user) }

    it 'revokes every one of the user\'s tokens, not just the one in params' do
      token
      other_token

      delete :destroy, params: { access_token: token.token }

      expect(token.reload.revoked?).to be(true)
      expect(other_token.reload.revoked?).to be(true)
    end

    it 'clears the JWT session cookies' do
      delete :destroy
      expect(response.cookies['etm_session']).to be_blank
      expect(response.cookies['etm_refresh']).to be_blank
      expect(response.cookies['etm_session_exp']).to be_blank
    end
  end

  context 'with a post_logout_redirect_uri' do
    before { sign_in(user) }

    it 'honours a registered redirect URI' do
      OAuthApplication.create!(
        name: 'Registered', uri: 'https://registered.example.com',
        redirect_uri: 'https://registered.example.com/auth/callback',
        owner: user, version: Version.default
      )

      delete :destroy, params: {
        access_token: token.token,
        post_logout_redirect_uri: 'https://registered.example.com'
      }

      expect(response).to redirect_to('https://registered.example.com')
    end

    it 'rejects an unregistered redirect URI and falls back to the application URI' do
      delete :destroy, params: {
        access_token: token.token,
        post_logout_redirect_uri: 'https://evil.example.com'
      }

      expect(response).to redirect_to('https://example.com')
    end
  end

  context 'when signing out with an access token that belongs to someone else' do
    before do
      token.update!(resource_owner_id: create(:user).id)
      sign_in(user)
    end

    it 'redirects to ETModel' do
      delete :destroy, params: { access_token: 'invalid' }
      expect(response).to redirect_to(Settings.etmodel_uri)
    end

    it 'does not revoke the token' do
      expect { delete(:destroy, params: { access_token: token.token }) }
        .not_to change { token.reload.revoked? }.from(false)
    end
  end
end
