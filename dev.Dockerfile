FROM ruby:3.4.3

# Install system dependencies
RUN --mount=target=/var/lib/apt/lists,type=cache,sharing=locked \
    --mount=target=/var/cache/apt,type=cache,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential \
    git \
    libpq-dev \
    libyaml-dev \
    postgresql-client \
    libvips \
    pkg-config \
    curl \
    vim \
    imagemagick \
    libffi-dev \
    libopenblas-dev \
    liblapack-dev \
    ffmpeg \
    gettext-base \
    wget

# Install Node.js and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

# sqlite-vec: on aarch64 the published gem ships a 32-bit binary, so we
# compile from source. On x86_64 the gem works out of the box.
RUN if [ "$(uname -m)" = "aarch64" ]; then \
      cd /tmp && \
      wget -q https://github.com/asg017/sqlite-vec/archive/refs/tags/v0.1.6.tar.gz && \
      tar xzf v0.1.6.tar.gz && \
      cd sqlite-vec-0.1.6 && \
      make loadable && \
      mkdir -p /usr/local/lib/sqlite-vec && \
      cp dist/vec0.so /usr/local/lib/sqlite-vec/ && \
      rm -rf /tmp/v0.1.6.tar.gz /tmp/sqlite-vec-0.1.6; \
    fi

# Set working directory
WORKDIR /app

# Install application gems + sqlite-vec
COPY Gemfile Gemfile.lock ./
RUN ARCH=$(uname -m) && \
    if [ "$ARCH" = "aarch64" ]; then \
      gem install sqlite-vec -v 0.1.6 --platform arm64-linux --ignore-dependencies && \
      bundle install && \
      find /usr/local/bundle/gems/sqlite-vec-*/lib -name vec0.so -exec cp /usr/local/lib/sqlite-vec/vec0.so {} \; ; \
    elif [ "$ARCH" = "x86_64" ]; then \
      gem install sqlite-vec -v 0.1.6 --platform x86_64-linux --ignore-dependencies && \
      bundle install; \
    else \
      bundle install; \
    fi

# Add a script to be executed every time the container starts
COPY entrypoint.dev.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.dev.sh
ENTRYPOINT ["entrypoint.dev.sh"]

EXPOSE 3000

# Start the main process
CMD ["bundle", "exec", "bin/dev"]
