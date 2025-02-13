require 'active_record/fixtures'

Dir[Rails.root.join("db/seed", "*.{yml,csv}").to_s].each do |file|
  Fixtures.create_fixtures("db/seed", File.basename(file, '.*'))
end

password  = SecureRandom.base58(8)
email     =    "seeded_admin@localdevelopment.com"

User.create!(
  name:     'Seeded Admin',
  admin:    true,
  password: password,
  email:    email
)

puts <<~MSG
  +------------------------------------------------------------------------------+
  |         Created admin user 'Seeded Admin' with password: #{password}         |
  |           and email: #{email}.                                               |
  | Please change this password if you're deploying to a production environment! |
  +------------------------------------------------------------------------------+
MSG
