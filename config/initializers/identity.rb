Identity.configure do |config|
  config.client_id = 'test_client_id'           # Dummy value for tests
  config.client_secret = 'test_client_secret'   # Dummy value for tests
  config.issuer = 'http://localhost:3002'
  config.client_uri = 'http://localhost:3002/callback'
  config.scope = 'public'
end
