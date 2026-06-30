# syntax = docker/dockerfile:1

# Development image: single stage, all gem groups (no BUNDLE_WITHOUT), source mounted,
# assets compiled on the fly. Used by this repo's docker-compose.yml and by ETLauncher /
# etm-stack via `build.context: ../MyETM`. The deploy build lives in Dockerfile.production.
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

COPY . .

CMD ["bundle", "exec", "rails", "server", "-b", "0.0.0.0", "-p", "3000"]
