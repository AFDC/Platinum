source 'https://rubygems.org'

gem 'rails', '3.2.12'

# Backend
# gem 'airbrake'
# gem 'newrelic_rpm'
gem 'json'
gem 'multi_json'
gem 'mysql2'
gem 'mongoid'
gem 'declarative_authorization'

# Frontend
gem 'active_link_to'
gem 'bootstrap-sass'
gem 'bootstrap-will_paginate'
gem 'bootstrap_form'
gem 'haml'
gem 'jquery-rails'
gem 'will_paginate'
gem "font-awesome-rails"


# Gems used only for assets and not required
# in production environments by default.
group :assets do
  gem 'sass-rails',   '~> 3.2.3'
  gem 'coffee-rails', '~> 3.2.1'
  gem 'uglifier', '>= 1.0.3'
  gem 'therubyracer'
end

group :development, :test do
  gem 'faker'
  gem 'guard-rspec'
  gem 'guard-spork'
  gem 'rspec-rails'
end

group :development do
  gem 'foreman'
  gem 'annotate'
  gem 'haml-rails'
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false
  gem 'terminal-notifier-guard'
end

group :test do
  gem 'capybara'
  gem 'cucumber-rails', require: false
  gem 'database_cleaner'
  gem 'factory_girl_rails'
  gem 'spork'
end

group :ops do
  gem 'pry'
  gem 'unicorn'
  gem 'figaro'
  gem 'capistrano'
end

# To use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.0.0'

# To use Jbuilder templates for JSON
# gem 'jbuilder'