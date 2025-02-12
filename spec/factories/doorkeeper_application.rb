FactoryBot.define do
  factory :doorkeeper_application, class: "Doorkeeper::Application" do
    name { "Test App" }
    uid { SecureRandom.hex(10) }
    secret { SecureRandom.hex(20) }
    redirect_uri { "https://redirect.com/callback" }
    uri { "https://site.com" }
    owner_id { 1 }
    owner_type { 'user' }
  end
end
