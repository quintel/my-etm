Sentry.init do |config|
  config.dsn = 'https://60adefe39e63b5ed6dd418b3fc8b16ca@o187050.ingest.us.sentry.io/4508620397871104'

  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for tracing.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = 0.2
  # or
  config.traces_sampler = lambda do |context|
    true
  end
  # Set profiles_sample_rate to profile 100%
  # of sampled transactions.
  # We recommend adjusting this value in production.
  config.profiles_sample_rate = 0.2
end