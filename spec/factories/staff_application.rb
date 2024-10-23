FactoryBot.define do
  factory :staff_application do
    transient do
      name { 'etmodel' }
    end

    user
    application { create(:oauth_application, owner: user) }

    after(:build) do |staff_application, evaluator|
      staff_application.name = evaluator.name
    end
  end

  factory :oauth_application, class: 'Doorkeeper::Application' do
    name { 'Default App' }
    uid { SecureRandom.hex(8) }
    secret { SecureRandom.hex(16) }
    redirect_uri { 'https://example.com/callback' }
    scopes { '' }
    confidential { true }
    uri { 'https://example.com' }
    owner { association(:user) }
  end
end
