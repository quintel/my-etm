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

  end

  # Logout is browser-scoped: it revokes the anchor token behind *this* browser's refresh cookie
  # and nothing else. See JwtSessionCookies#revoke_jwt_session.
  context 'when signing out with a browser session' do
    let(:anchor) do
      user.access_tokens.create!(
        expires_in: JwtSessionCookies::ACCESS_TTL,
        scopes: JwtSessionCookies::SESSION_SCOPES,
        use_refresh_token: true
      )
    end

    before do
      sign_in(user)
      request.cookies[JwtSessionCookies::REFRESH_COOKIE] = anchor.refresh_token
    end

    it 'revokes the anchor token for this browser' do
      expect { delete(:destroy) }.to change { anchor.reload.revoked? }.from(false).to(true)
    end

    it 'leaves the personal access tokens of the same user alone' do
      pat = CreatePersonalAccessToken.call(
        user: user, params: { name: 'pipeline', permissions: :read }
      ).value!

      delete :destroy

      expect(pat.oauth_access_token.reload.revoked?).to be(false)
    end

    it 'leaves the same user\'s session on another device alone' do
      other_browser = user.access_tokens.create!(
        expires_in: JwtSessionCookies::ACCESS_TTL,
        scopes: JwtSessionCookies::SESSION_SCOPES,
        use_refresh_token: true
      )

      delete :destroy

      expect(other_browser.reload.revoked?).to be(false)
    end
  end

  # #create deliberately drops the Warden session, so a real sign-out arrives carrying only the JWT
  # cookies. The other examples here use Devise's sign_in helper, which leaves a Warden session the
  # app never actually has; this context reproduces what the browser sends.
  context 'when signing out with only the shared session cookies' do
    let(:anchor) do
      user.access_tokens.create!(
        expires_in: JwtSessionCookies::ACCESS_TTL,
        scopes: JwtSessionCookies::SESSION_SCOPES,
        use_refresh_token: true
      )
    end

    before do
      request.cookies[JwtSessionCookies::SESSION_COOKIE] = anchor.token
      request.cookies[JwtSessionCookies::REFRESH_COOKIE] = anchor.refresh_token
    end

    it 'revokes the anchor token' do
      expect { delete(:destroy) }.to change { anchor.reload.revoked? }.from(false).to(true)
    end

    it 'clears the JWT session cookies' do
      delete :destroy

      expect(response.cookies['etm_session']).to be_blank
      expect(response.cookies['etm_refresh']).to be_blank
      expect(response.cookies['etm_session_exp']).to be_blank
    end

    it 'redirects to ETModel' do
      delete :destroy
      expect(response).to redirect_to(Settings.etmodel_uri)
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

    # Logout no longer sweeps the user's tokens: the other apps are signed out by the parent-domain
    # access cookie being cleared, not by revocation. Revoking by user is what used to destroy the
    # user's personal access tokens as a side effect of a web logout.
    it 'leaves tokens belonging to other applications alone' do
      token
      other_token

      delete :destroy, params: { access_token: token.token }

      expect(other_token.reload.revoked?).to be(false)
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
