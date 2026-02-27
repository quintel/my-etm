if Settings.sentry_dsn
  Sentry.init do |config|
    config.dsn = Settings.sentry_dsn
    config.release = Settings.release
    config.enabled_environments = %w[production staging]

    # Use OpenTelemetry for instrumentation instead of Sentry's native instrumentation
    config.instrumenter = :otel

    # Set traces_sample_rate to capture 20% of transactions for tracing
    config.traces_sample_rate = 0.2

    # Set profiles_sample_rate to profile 20% of sampled transactions
    config.profiles_sample_rate = 0.2
  end
end
