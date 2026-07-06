# frozen_string_literal: true

RSpec.describe RevokeUserSessions do
  let(:user) { create(:user) }

  let(:application) do
    OAuthApplication.create!(
      name: 'App', uri: 'https://app.example.com',
      redirect_uri: 'https://app.example.com/auth/callback',
      owner: user, version: Version.default
    )
  end

  it 'revokes all active access tokens for the user' do
    token = Doorkeeper::AccessToken.create!(application:, resource_owner_id: user.id)

    expect { described_class.call(user) }
      .to change { token.reload.revoked? }.from(false).to(true)
  end

  it 'revokes all active access grants for the user' do
    grant = Doorkeeper::AccessGrant.create!(
      application:, resource_owner_id: user.id,
      redirect_uri: application.redirect_uri, expires_in: 600, scopes: 'public'
    )

    expect { described_class.call(user) }
      .to change { grant.reload.revoked? }.from(false).to(true)
  end

  it 'leaves already-revoked tokens untouched' do
    revoked_at = 1.hour.ago
    token = Doorkeeper::AccessToken.create!(
      application:, resource_owner_id: user.id, revoked_at:
    )

    expect { described_class.call(user) }
      .not_to(change { token.reload.revoked_at.to_i })
  end

  it 'does not revoke another user\'s tokens' do
    other = create(:user)
    token = Doorkeeper::AccessToken.create!(application:, resource_owner_id: other.id)

    expect { described_class.call(user) }
      .not_to change { token.reload.revoked? }.from(false)
  end
end
