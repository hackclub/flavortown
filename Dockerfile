# syntax=docker/dockerfile:1
# check=error=true;skip=SecretsUsedInArgOrEnv

# This Dockerfile is designed for production, not development. Use with Kamal or build'n'run by hand:
# docker build -t battlemage .
# docker run -d -p 80:80 -e RAILS_MASTER_KEY=<value from config/master.key> --name battlemage battlemage

# For a containerized dev environment, see Dev Containers: https://guides.rubyonrails.org/getting_started_with_devcontainer.html

# Make sure RUBY_VERSION matches the Ruby version in .ruby-version
ARG RUBY_VERSION=3.4.3
FROM docker.io/library/ruby:$RUBY_VERSION-slim AS base

# Rails app lives here
WORKDIR /rails

# Install base packages
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    curl \
    wget \
    procps \
    lsof \
    strace \
    less \
    libjemalloc2 \
    libvips \
    imagemagick \
    file \
    git \
    libopenblas0 \
    liblapack3 \
    ffmpeg && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

# Set production environment
ENV RAILS_ENV="production" \
    BUNDLE_DEPLOYMENT="1" \
    BUNDLE_PATH="/usr/local/bundle" \
    BUNDLE_WITHOUT="development"

# Throw-away build stage to reduce size of final image
FROM base AS build

# Install packages needed to build gems
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libyaml-dev \
    pkg-config \
    libffi-dev \
    libopenblas-dev \
    liblapack-dev && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Install Node.js, npm, and Yarn for jsbundling (esbuild)
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y nodejs npm && \
    npm install -g yarn && \
    rm -rf /var/lib/apt/lists /var/cache/apt/archives

# Build sqlite-vec from source for aarch64 (the published gem ships a 32-bit binary)
RUN cd /tmp && \
    wget -q https://github.com/asg017/sqlite-vec/archive/refs/tags/v0.1.6.tar.gz && \
    tar xzf v0.1.6.tar.gz && \
    cd sqlite-vec-0.1.6 && \
    make loadable 2>/dev/null && \
    mkdir -p /usr/local/lib/sqlite-vec && \
    cp dist/vec0.so /usr/local/lib/sqlite-vec/ && \
    rm -rf /tmp/v0.1.6.tar.gz /tmp/sqlite-vec-0.1.6

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN gem install sqlite-vec -v 0.1.6 --platform arm64-linux --ignore-dependencies && \
    bundle install && \
    find /usr/local/bundle/gems/sqlite-vec-*/lib -name vec0.so -exec cp /usr/local/lib/sqlite-vec/vec0.so {} \; && \
    rm -rf ~/.bundle/ "${BUNDLE_PATH}"/ruby/*/cache "${BUNDLE_PATH}"/ruby/*/bundler/gems/*/.git && \
    bundle exec bootsnap precompile --gemfile

# Install JavaScript dependencies for jsbundling-rails
COPY package.json yarn.lock ./
RUN yarn install --frozen-lockfile && yarn cache clean

# Copy application code
COPY . .

# Precompile bootsnap code for faster boot times
RUN bundle exec bootsnap precompile app/ lib/

# Precompiling assets for production without requiring secret RAILS_MASTER_KEY
RUN SECRET_KEY_BASE_DUMMY=1 ./bin/rails assets:precompile




# Final stage for app image
FROM base

# Copy built artifacts: gems, application
COPY --from=build "${BUNDLE_PATH}" "${BUNDLE_PATH}"
COPY --from=build /rails /rails

# Run and own only the runtime files as a non-root user for security
RUN groupadd --system --gid 1000 rails && \
    useradd rails --uid 1000 --gid 1000 --create-home --shell /bin/bash && \
    chown -R rails:rails db log storage tmp public
USER 1000:1000

# Entrypoint prepares the database.
ENTRYPOINT ["/rails/bin/docker-entrypoint"]

# Start server via Thruster by default, this can be overwritten at runtime
EXPOSE 80
CMD ["./bin/thrust", "./bin/rails", "server"]
