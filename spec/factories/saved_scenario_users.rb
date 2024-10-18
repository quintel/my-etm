FactoryBot.define do
  factory :saved_scenario_user do
    role_id { User::ROLES.key(:scenario_owner) }

    # user
    # TODO: when we have User, swap email for user!
    user_email { 'me@you.me' }
  end
end
