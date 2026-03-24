# frozen_string_literal: true

# Disable built-in HTTP Basic auth — access is controlled by the
# authenticate :user block in routes.rb, which requires admin?.
MissionControl::Jobs.http_basic_auth_enabled = false
