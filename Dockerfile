# syntax = docker/dockerfile:1

# Base Stage: Ruby and dependencies
ARG RUBY_VERSION=3.3.5-slim
FROM ruby:${RUBY_VERSION} AS base

LABEL maintainer="dev@quintel.com"

# Set working directory
WORKDIR /app

# Install required base packages
RUN apt-get update -yqq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yqq --no-install-recommends \
      build-essential \
      default-mysql-client \
      libjemalloc2 \
      libvips \
      nodejs \
      git \
      gnupg && \
    rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Set environment variables for production
ENV RAILS_ENV=production \
    BUNDLE_DEPLOYMENT=1 \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development:test" \
    SECRET_KEY_BASE_DUMMY=1

# Throw-away Build Stage: Gems and assets
FROM base AS build

# Install additional build tools for native extensions
RUN apt-get update -yqq && \
    apt-get install --no-install-recommends -y \
      default-libmysqlclient-dev \
      git \
      pkg-config && \
    rm -rf /var/lib/apt/lists /tmp/* /var/tmp/*

# Copy Gemfile and install dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install && \
    rm -rf ~/.bundle "${BUNDLE_PATH}/ruby/*/cache" "${BUNDLE_PATH}/ruby/*/bundler/gems/*/.git"

# Copy application code
COPY . .

# Precompile Rails assets
RUN bundle exec rails assets:precompile && \
    bundle exec bootsnap precompile app/ lib/

# Final Stage: Minimal runtime image
FROM base

# Copy built gems and application from the build stage
COPY --from=build ${BUNDLE_PATH} ${BUNDLE_PATH}
COPY --from=build /app /app

# Create a non-root user for runtime
RUN groupadd --system rails && \
    useradd --system --gid rails --create-home rails && \
    chown -R rails:rails /app
USER rails

# Expose Rails server port
EXPOSE 3000

# Entrypoint to prepare the database
ENTRYPOINT ["./bin/docker-entrypoint"]

# Default command to start Rails server
CMD ["./bin/rails", "server", "-b", "0.0.0.0"]
