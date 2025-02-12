# frozen_string_literal: true

FactoryBot.define do
  factory :personal_access_token do
    name { 'My Personal Access Token' }
    user { create(:user) }
    oauth_access_token do
      create(:access_token_read, resource_owner_id: user.id)
    end
  end

  factory :expired_personal_access_token, parent: :personal_access_token do
    name { 'My Expired Personal Access Token' }
    user { create(:user) }
    oauth_access_token { create(:access_token_expired, resource_owner_id: user.id) }
  end
end
