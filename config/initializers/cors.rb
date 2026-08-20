# Same-registrable-domain ETM apps call session refresh and the API cross-subdomain with the shared
# cookie (credentialed), so they need a specific-origin grant (the CORS spec forbids credentials with
# a wildcard origin). Defaults cover every prod and dev ETM subdomain; override with
# CORS_SESSION_ORIGINS (comma-separated) if needed.
SESSION_CORS_ORIGINS =
  ENV["CORS_SESSION_ORIGINS"].to_s.split(",").map(&:strip).presence || [
    %r{\Ahttps?://([a-z0-9-]+\.)*energytransitionmodel\.com(:\d+)?\z},
    %r{\Ahttps?://([a-z0-9-]+\.)*etm\.test(:\d+)?\z}
  ]

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*SESSION_CORS_ORIGINS)
    resource '/session/*',
      headers: :any,
      credentials: true,
      methods: [:post, :options]
    resource '/api/*',
      headers: :any,
      credentials: true,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end

  # Token/PAT API clients authenticate with a bearer header (no cookies), so any origin is allowed.
  allow do
    origins '*'
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head]
  end
end
