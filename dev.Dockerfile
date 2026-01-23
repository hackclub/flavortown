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
    liblapack-dev

# Install Node.js and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

# Set working directory
WORKDIR /app

# Install application dependencies
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Add a script to be executed every time the container starts
COPY entrypoint.dev.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.dev.sh
ENTRYPOINT ["entrypoint.dev.sh"]

EXPOSE 3000

# Start the main process
CMD ["bundle", "exec", "bin/dev"]
