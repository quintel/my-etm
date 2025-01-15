Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins do |origin, _env|
      # Allow requests from *.energytransitionmodel.com
      origin =~ /\.energytransitionmodel\.com$/ || origin == 'energytransitionmodel.com'
    end
    resource '/oauth/*',
      headers: :any,
      methods: [:get, :post, :options],
      credentials: true

    # Retain API-specific configuration
    resource '/api/*',
      headers: :any,
      methods: [:get, :post, :put, :patch, :delete, :options, :head],
      credentials: true
  end
end
