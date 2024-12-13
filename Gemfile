source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 7.2.1"
# The original asset pipeline for Rails [https://github.com/rails/sprockets-rails]
gem "sprockets-rails"
# Use mysql as the database for Active Record
gem "mysql2", "~> 0.5.5"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"
# Use JavaScript with ESM import maps [https://github.com/rails/importmap-rails]
gem "importmap-rails"
# Hotwire's SPA-like page accelerator [https://turbo.hotwired.dev]
gem "turbo-rails"
# Hotwire's modest JavaScript framework [https://stimulus.hotwired.dev]
gem "stimulus-rails"
# Build JSON APIs with ease [https://github.com/rails/jbuilder]
gem "jbuilder"
# Use Redis adapter to run Action Cable in production
# gem "redis", ">= 4.0.1"

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem "kredis"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem "bcrypt", "~> 3.1.7"

gem 'rake'


# Auth
gem 'cancancan', '~> 3.0'
gem 'devise', '~> 4.7'
gem 'doorkeeper-openid_connect', '~> 1.8.7'
gem 'faraday'
gem 'jwt'
gem 'json-jwt'
gem 'sidekiq'
gem "sentry-sidekiq"
gem 'http_accept_language'
gem 'listen'
gem 'config'
gem 'rack-cors',                      require: 'rack/cors'
gem 'activerecord-session_store'

# Views and CSS
gem 'haml'
gem "tailwindcss-rails", "~> 3.0"
gem 'view_component'
gem "rdiscount", "~> 2.2"
gem "heroicon"
gem 'dry-initializer'
gem 'dry-monads'
gem 'dry-struct'
gem 'dry-validation'
gem 'inline_svg'
gem 'local_time'
gem 'erb-formatter'
gem 'pagy'

# Testing
gem 'capybara'

# Model gems
gem 'discard'

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Use Active Storage variants [https://guides.rubyonrails.org/active_storage_overview.html#transforming-images]
gem "image_processing", "~> 1.2"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false

  # Test suite
  gem "rspec-rails"
  gem "factory_bot_rails"
  gem 'shoulda-matchers'
  gem "rails-controller-testing"
end

# Use console on exceptions pages [https://github.com/rails/web-console]
gem 'web-console', group: :development

gem "invisible_captcha", "~> 2.3"
