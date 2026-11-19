# frozen_string_literal: true

require "rails_helper"

RSpec.describe PersonalAccessToken do
  describe ".record_use" do
    let(:access_token) { create(:access_token, resource_owner_id: create(:user).id) }
    let(:personal) do
      described_class.create!(oauth_access_token: access_token, name: "Test", user_id: access_token.resource_owner_id)
    end
    let(:now) { Time.now.utc.change(usec: 0) }

    def record = described_class.record_use(access_token.id, now)

    it "records a first use" do
      personal.update!(last_used_at: nil)

      expect { record }.to change { personal.reload.last_used_at }.from(nil).to(now)
    end

    it "records a use once the last is older than the granularity" do
      personal.update!(last_used_at: now - 3.minutes)

      expect { record }.to change { personal.reload.last_used_at }.to(now)
    end

    it "skips a use while the last is recent" do
      personal.update!(last_used_at: now - 1.minute)

      expect { record }.not_to(change { personal.reload.last_used_at })
    end
  end
end
