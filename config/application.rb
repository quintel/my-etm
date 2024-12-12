require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module MyEtm
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.2

    # Configuration for the application, engines, and railties goes here.
    config.autoload_paths << Rails.root.join("lib")
    config.autoload_paths << Rails.root.join("app/components")


    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    config.i18n.enforce_available_locales = true
    config.i18n.available_locales = %i[en nl]
    config.i18n.default_locale = :en

    config.active_support.deprecation = :log

    config.encoding = "utf-8"

    config.filter_parameters << :password
    # Don't generate system test files.
    config.generators.system_tests = nil

    config.to_prepare do
      Doorkeeper::AuthorizationsController.layout 'login'
      Doorkeeper::AuthorizedApplicationsController.layout 'identity'
    end

    config.generators do |g|
      g.template_engine :haml
      g.test_framework  :rspec, fixture: false
    end

    # Mail
    if (email_conf = Rails.root.join('config/email.yml')).file?
      email_env_conf = YAML.load_file(email_conf)[Rails.env]

      if email_env_conf
        config.action_mailer.smtp_settings = email_env_conf.symbolize_keys
      else
        raise "Missing e-mail settings for #{ Rails.env.inspect } environment"
      end
    end
  end
  Date::DATE_FORMATS[:default] = "%d-%m-%Y"
end
