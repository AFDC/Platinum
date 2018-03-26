# This file is used by Rack-based servers to start the application.

require ::File.expand_path('../config/environment',  __FILE__)
run Platinum::Application

if ENV['sidekiq_path']
  map ENV['sidekiq_path'] do
    use Rack::Session::Cookie, key: 'sidekiq.session', secret: ENV['secret_token']
    use Rack::Protection::AuthenticityToken
    run Sidekiq::Web
  end
end
