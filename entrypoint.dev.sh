#!/bin/bash
set -e

if [ -f "package.json" ]; then
  echo "Checking/Installing JavaScript dependencies..."
  yarn install
fi

# Remove a potentially pre-existing server.pid for Rails.
rm -f /app/tmp/pids/server.pid

# Then exec the container's main process (what's set as CMD in the Dockerfile).
exec "$@"
