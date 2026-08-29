# Build libheif from source
FROM ruby:3.4.3-slim AS libheif-build
ARG LIBHEIF_VERSION=1.23.2
ARG LIBHEIF_SHA256=1405ed070421459b569ff49deab109b7f1a30a447e72a9b20a4154f774634a44
RUN apt-get update -qq && \
    apt-get install --no-install-recommends -y \
    build-essential cmake pkg-config curl ca-certificates \
    libaom-dev libde265-dev && \
    rm -rf /var/lib/apt/lists/* && \
    cd /tmp && \
    curl -sL "https://github.com/strukturag/libheif/archive/refs/tags/v${LIBHEIF_VERSION}.tar.gz" -o /tmp/libheif.tar.gz && \
    echo "${LIBHEIF_SHA256} /tmp/libheif.tar.gz" | sha256sum -c - && \
    tar xz -C /tmp/ -f /tmp/libheif.tar.gz && \
    cd /tmp/libheif-${LIBHEIF_VERSION} && \
    mkdir build && cd build && \
    cmake --preset=release -DWITH_EXAMPLES=ON -DENABLE_PLUGIN_LOADING=NO .. && \
    make -j$(nproc) && \
    make install && \
    ldconfig

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
    gettext-base

# Overlay libheif from build stage
COPY --from=libheif-build /usr/local/lib/libheif* /usr/local/lib/
COPY --from=libheif-build /usr/local/bin/heif-* /usr/local/bin/
COPY --from=libheif-build /usr/local/include/libheif /usr/local/include/libheif
RUN ldconfig

ENV LD_LIBRARY_PATH="/usr/local/lib"

# Install Node.js and Yarn
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - && \
    apt-get install -y nodejs && \
    npm install --global yarn

# Set working directory
WORKDIR /app

# Install application gems
COPY Gemfile Gemfile.lock ./
RUN bundle install

# Add a script to be executed every time the container starts
COPY entrypoint.dev.sh /usr/bin/
RUN chmod +x /usr/bin/entrypoint.dev.sh
ENTRYPOINT ["entrypoint.dev.sh"]

EXPOSE 3000

# Start the main process
CMD ["bundle", "exec", "bin/dev"]
