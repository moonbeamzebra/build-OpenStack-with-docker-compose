#!/usr/bin/env bash
set -euo pipefail

echo "Starting Glance container..."

echo "Waiting for PostgreSQL..."
wait_for_postgreSQL.sh

echo "Running Glance setup..."
glance-setup.sh

echo "Starting glance-api..."

exec /usr/bin/glance-api \
    --config-file=/etc/glance/glance-api.conf
