FactoryBot.define do
  factory :saved_scenario_user do
    role_id { User::Roles.index_of(:scenario_owner) }
    saved_scenario
    association :user

    trait :with_email do
      user { nil }
      user_email { "user@example.com" }
    end
  end
end
