# frozen_string_literal: true
require_relative 'staff_applications/app_config'

module MyEtm
  # Holds config information about OAuth accounts created for staff users.
  module StaffApplications
    class << self
      def all
        [etengine, etmodel, collections]
      end

      def find(key)
        case key.to_sym
        when :etengine then etengine
        when :etmodel then etmodel
        when :collections then collections
        else raise ArgumentError, "unknown application: #{key}"
        end
      end

      private

      # TODO fix these app configs - include Engine!

      def etengine
        AppConfig.new(
          key: 'etengine',
          name: 'Engine (Local)',
          scopes: 'openid email profile public scenarios:read scenarios:write scenarios:delete',
          uri: 'http://localhost:3000',
          redirect_path: '/auth/identity/callback',
          run_command: 'bundle exec rails server -p %<port>s',
          config_path: 'config/settings.local.yml',
          config_content: <<~YAML,
            idp_url: %<myetm_url>s
            ete_url: %<etengine_url>s

            identity:
              client_id: %<uid>s
              client_secret: %<secret>s
              client_uri: %<uri>s

            collections_url: %<collections_url>s
          YAML
        )
      end

      def etmodel
        AppConfig.new(
          key: 'etmodel',
          name: 'Model (Local)',
          scopes: 'openid email profile roles public scenarios:read scenarios:write scenarios:delete',
          uri: 'http://localhost:3001',
          redirect_path: '/auth/identity/callback',
          run_command: 'bundle exec rails server -p %<port>s',
          config_path: 'config/settings.local.yml',
          config_content: <<~YAML,
            api_url: %<etmodel_url>s

            identity:
              client_id: %<uid>s
              client_secret: %<secret>s
              client_uri: %<uri>s

            collections_url: %<collections_url>s
          YAML
        )
      end

      def collections
        AppConfig.new(
          key: 'collections',
          name: 'Collections (Local)',
          scopes: 'openid email profile public scenarios:read scenarios:write',
          uri: 'http://localhost:3005',
          redirect_path: '/api/auth/callback/identity',
          run_command: 'yarn dev -p %<port>s',
          config_path: '.env.local',
          config_content: <<~ENV,
            # Protocol and host for MyETM. No trailing slash please.
            NEXT_PUBLIC_MYETM_URL=%<myetm_url>s

            # Protocol and host for ETModel. No trailing slash please.
            NEXT_PUBLIC_ETMODEL_URL=%<etmodel_url>s

            # Authentication.
            NEXTAUTH_URL=%<myetm_url>s
            NEXTAUTH_SECRET=none
            AUTH_CLIENT_ID=%<uid>s
            AUTH_CLIENT_SECRET=%<secret>s

          ENV
        )
      end
    end
  end
end
