FROM ruby:2.6.10
MAINTAINER Pete Holiday <pete.holiday@gmail.com>

RUN mkdir -p /var/app
COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
WORKDIR /var/app
RUN gem install libv8-node:16.19.0.1
RUN gem install mini_racer:0.6.4
RUN gem install bundler -v 1.17
RUN bundle install

COPY . .
CMD bundle exec puma -C config/puma.rb
