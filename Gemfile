source 'https://rubygems.org'

gem 'rails', '~> 4.2'

gem 'mimemagic', git: 'https://github.com/mimemagicrb/mimemagic', ref: '01f92d86d15d85cfd0f20dabd025dcbd36a8a60f'

# Backend
gem 'json'
gem 'mongoid', '~> 4.0.0'
gem 'declarative_authorization'
gem 'mongoid-paperclip', '~> 0.0.11', require: 'mongoid_paperclip'
gem 'ruby_parser'
gem 'smarter_csv'
gem 'actionmailer'
gem 'bcrypt'
gem 'dalli'
gem 'premailer-rails'
gem 'nokogiri'
gem 'braintree', '~> 2.101.0'
gem 'twilio-ruby', '~> 5.10.7'
gem 'puma'
gem 'bugsnag', '~> 5.1.0'
gem 'gibbon', '~> 3.0'

# Job Processing
gem 'sidekiq', '~> 4.2.10'
gem 'sidekiq-cron', '~> 0.4.5'
gem 'sinatra', '~> 1.4.4', require: false
gem 'slim', '~> 2.0.2'
gem 'whenever', '~> 0.9.4'

# Frontend
gem 'active_link_to', '~> 1.0.0'
gem 'bootstrap-sass', '~> 2.3.1.0'
gem 'bootstrap-will_paginate', '~> 1.0.0'
gem 'bootstrap_form', '~> 2.1.1'
gem 'haml', '~> 4.0.1'
gem 'jquery-rails', '~> 2.2.1'
gem 'will_paginate', '~> 3.1.6'
gem "font-awesome-rails", '~> 3.2.1.0'



group :development, :test do
  gem 'sass-rails'
  gem 'faker', '~> 1.1.2'
  gem 'rspec-rails', '~> 4.1.2'
  gem 'better_errors', '~> 1.1.0'
  gem 'binding_of_caller', '~> 1.0.0'
  gem 'dotenv', require: 'dotenv/load'
end

group :development do
  gem "web-console", "~> 2.0"
  gem 'annotate', '~> 2.5.0'
  gem 'haml-rails', '~> 0.4'
  gem 'rb-inotify', '~> 0.9.0', require: false
  gem 'rb-fsevent', '~> 0.9.3', require: false
  gem 'rb-fchange', '~> 0.0.6', require: false
  gem 'terminal-notifier-guard', '~> 1.5.3'
  gem 'thin', '~> 1.8.2'
end

group :test do
  gem 'factory_girl_rails', '~> 4.2.1'
  gem 'spork', '~> 0.9.2'
  gem 'test-unit'
end

group :ops do
  gem 'pry', '~> 0.9.12'
end

# To use ActiveModel has_secure_password


# To use Jbuilder templates for JSON
# gem 'jbuilder'
