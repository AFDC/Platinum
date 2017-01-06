FROM ruby:2.1
MAINTAINER Pete Holiday <pete.holiday@gmail.com>

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /var/app
COPY Gemfile /var/app/Gemfile
COPY Gemfile.lock /var/app/Gemfile.lock
WORKDIR /var/app
RUN bundle install

COPY . .
CMD bundle exec foreman start -f DevProcfile
