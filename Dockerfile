FROM ruby:2.1
MAINTAINER Pete Holiday <pete.holiday@gmail.com>

RUN mkdir -p /var/app
COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
WORKDIR /var/app
RUN gem update bundler
RUN bundle install

COPY . .
CMD bundle exec puma -C config/puma.rb
