# syntax = docker/dockerfile:1

# Base Stage: Ruby and dependencies
ARG RUBY_VERSION=4.0.2-slim
FROM ruby:${RUBY_VERSION}

LABEL maintainer="info@energytransitionmodel.com"

WORKDIR /app

RUN apt-get update -yqq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
      build-essential \
      default-libmysqlclient-dev \
      default-mysql-client \
      git \
      gnupg \
      libjemalloc2 \
      libvips \
      libyaml-dev \
      nodejs \
      pkg-config && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY Gemfile Gemfile.lock ./
RUN bundle install
RUN bundle exec rails tailwindcss:build

COPY . .

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
