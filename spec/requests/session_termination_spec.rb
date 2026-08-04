# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Ending shared browser sessions', type: :request do
  let(:user) { create(:user, :confirmed_at) }

  before { Version.default }

  def anchor_for(owner)
    owner.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL,
      scopes: JwtSessionCookies::SESSION_SCOPES,
      use_refresh_token: true
    )
  end

  # This browser's cookies, as it presents them back.
  def session_cookies(anchor)
    { 'Cookie' => "etm_session=#{anchor.token}; etm_refresh=#{anchor.refresh_token}" }
  end

  describe 'POST /identity/change_password' do
    let(:here) { anchor_for(user) }
    let(:elsewhere) { anchor_for(user) }

    def change_password
      post '/identity/change_password',
        params: { user: { current_password: 'password', password: 'new-password' } },
        headers: session_cookies(here)
    end

    it 'ends the session on the user\'s other devices' do
      elsewhere
      change_password

      expect(response).to redirect_to(identity_profile_path)
      expect(elsewhere.reload.revoked?).to be(true)
    end

    it 'keeps the browser that changed the password signed in, on a fresh anchor' do
      change_password

      expect(response.cookies['etm_session']).to be_present
      expect(response.cookies['etm_refresh']).to be_present
      expect(response.cookies['etm_refresh']).not_to eq(here.refresh_token)
      expect(here.reload.revoked?).to be(true)
    end

    it 'leaves the sessions alone when the current password is wrong' do
      elsewhere

      post '/identity/change_password',
        params: { user: { current_password: '_wrong_', password: 'new-password' } },
        headers: session_cookies(here)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(elsewhere.reload.revoked?).to be(false)
      expect(here.reload.revoked?).to be(false)
    end
  end

  describe 'PUT /identity/password' do
    let(:reset_token) { user.send_reset_password_instructions }

    it 'ends the session on the user\'s other devices' do
      elsewhere = anchor_for(user)

      put '/identity/password', params: {
        user: {
          reset_password_token: reset_token,
          password: 'new-password',
          password_confirmation: 'new-password'
        }
      }

      expect(elsewhere.reload.revoked?).to be(true)
    end

    it 'signs the browser that reset the password in' do
      put '/identity/password', params: {
        user: {
          reset_password_token: reset_token,
          password: 'new-password',
          password_confirmation: 'new-password'
        }
      }

      expect(response.cookies['etm_session']).to be_present
      expect(response.cookies['etm_refresh']).to be_present
    end

    it 'ends no sessions when the token is invalid' do
      elsewhere = anchor_for(user)

      put '/identity/password', params: {
        user: {
          reset_password_token: 'invalid',
          password: 'new-password',
          password_confirmation: 'new-password'
        }
      }

      expect(elsewhere.reload.revoked?).to be(false)
      expect(response.cookies['etm_session']).to be_blank
    end
  end

  describe 'DELETE /identity' do
    let(:here) { anchor_for(user) }

    def delete_account
      delete '/identity',
        params: { user: { current_password: 'password' } },
        headers: session_cookies(here)
    end

    it 'clears the shared cookies, signing the account out of every ETM app' do
      delete_account

      expect(response.cookies['etm_session']).to be_blank
      expect(response.cookies['etm_refresh']).to be_blank
      expect(response.cookies['etm_session_exp']).to be_blank
    end

    it 'revokes the anchor tokens of every device' do
      elsewhere = anchor_for(user)
      delete_account

      expect(here.reload.revoked?).to be(true)
      expect(elsewhere.reload.revoked?).to be(true)
    end
  end

  describe 'a soft-deleted account' do
    it 'is signed out even while its row is still there' do
      anchor = anchor_for(user)
      user.update!(deleted_at: Time.current)

      get '/', headers: session_cookies(anchor)

      expect(response).to redirect_to(new_user_session_path)
    end
  end
end
