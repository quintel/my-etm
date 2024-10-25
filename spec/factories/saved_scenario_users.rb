FactoryBot.define do
  factory :saved_scenario_user do
    role_id { User::Roles.index_of(:scenario_owner) }

    user
  end
end
