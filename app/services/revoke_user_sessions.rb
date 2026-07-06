# frozen_string_literal: true

# Revokes all of a user's OAuth sessions across every client application, used to implement single
# logout. Doorkeeper's `revoke_all_for` is per-application, so we revoke via the user's associations
# in two bulk writes instead.
class RevokeUserSessions
  def self.call(user, now: Time.current)
    new(user, now).call
  end

  def initialize(user, now)
    @user = user
    @now = now
  end

  def call
    @user.access_tokens.where(revoked_at: nil).update_all(revoked_at: @now)
    @user.access_grants.where(revoked_at: nil).update_all(revoked_at: @now)
  end
end
