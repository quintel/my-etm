# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Api::V2::Caller do
  let(:user) { create(:user) }

  def session_cookie_jwt(scopes: JwtSessionCookies::SESSION_SCOPES, owner: user)
    owner.access_tokens.create!(
      expires_in: JwtSessionCookies::ACCESS_TTL, scopes: scopes, use_refresh_token: true
    ).token
  end

  def pat(scopes: 'public scenarios:read', owner: user, expires_in: 1.hour.to_i, **attrs)
    create(:access_token, resource_owner_id: owner.id, scopes:, expires_in:, **attrs)
  end

  describe 'from_cookie' do
    it 'resolves the user the cookie was minted for' do
      expect(described_class.from_cookie(session_cookie_jwt).user).to eq(user)
    end

    it 'exposes the granted scopes as a list, not the raw claim string' do
      expect(described_class.from_cookie(session_cookie_jwt).scopes)
        .to eq(JwtSessionCookies::SESSION_SCOPES.split)
    end

    it 'refuses a blank credential' do
      expect(described_class.from_cookie(nil)).to be_nil
      expect(described_class.from_cookie('')).to be_nil
    end

    it 'refuses a credential that is not a signed JWT' do
      expect(described_class.from_cookie('not-a-jwt')).to be_nil
    end

    # A PAT's audience deliberately excludes MyETM, so local verification rejects one.
    it 'refuses a personal access token presented as a cookie' do
      expect(described_class.from_cookie(pat.token)).to be_nil
    end

    it 'refuses a cookie whose subject no longer exists' do
      jwt = session_cookie_jwt
      user.destroy

      expect(described_class.from_cookie(jwt)).to be_nil
    end
  end

  describe 'from_bearer' do
    it 'resolves the user the token belongs to' do
      expect(described_class.from_bearer(pat.token).user).to eq(user)
    end

    it 'exposes the granted scopes as a list' do
      expect(described_class.from_bearer(pat(scopes: 'public scenarios:read').token).scopes)
        .to eq(%w[public scenarios:read])
    end

    it 'refuses a revoked token' do
      token = pat
      token.update!(revoked_at: Time.now.utc)

      expect(described_class.from_bearer(token.token)).to be_nil
    end

    it 'refuses an expired token' do
      token = pat(expires_in: 60)
      token.update!(created_at: 2.hours.ago)

      expect(described_class.from_bearer(token.token)).to be_nil
    end

    it 'refuses a credential no stored token matches' do
      expect(described_class.from_bearer('nonexistent')).to be_nil
      expect(described_class.from_bearer(nil)).to be_nil
    end
  end

  it 'produces the same shape for both access lanes for the same user' do
    scopes = 'public scenarios:read'

    from_cookie = described_class.from_cookie(session_cookie_jwt(scopes: "roles #{scopes}"))
    from_bearer = described_class.from_bearer(pat(scopes: scopes).token)

    expect(from_cookie.user).to eq(from_bearer.user)
    expect(from_cookie.scopes).to include(*from_bearer.scopes)
  end
end
