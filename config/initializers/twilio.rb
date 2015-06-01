Twilio.configure do |config|
  config.account_sid = ENV['twilio_sid']
  config.auth_token  = ENV['twilio_token']
end
