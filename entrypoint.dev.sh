#!/bin/bash
set -e

# Ensure gems are installed (needed when bundle_cache volume is fresh)
bundle check || bundle install

# sqlite-vec: on aarch64, replace the broken 32-bit .so with our compiled one
if [ "$(uname -m)" = "aarch64" ] && [ -f /usr/local/lib/sqlite-vec/vec0.so ]; then
  gem install sqlite-vec -v 0.1.6 --platform arm64-linux --ignore-dependencies --install-dir /usr/local/bundle 2>/dev/null || true
  find /usr/local/bundle/gems/sqlite-vec-*/lib -name vec0.so -exec cp /usr/local/lib/sqlite-vec/vec0.so {} \; 2>/dev/null || true
fi

if [ -f "package.json" ]; then
  echo "Checking/Installing JavaScript dependencies..."
  yarn install
fi

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
