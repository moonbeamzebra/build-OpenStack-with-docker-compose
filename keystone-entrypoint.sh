#!/usr/bin/env bash
set -euo pipefail

echo "Waiting for PostgreSQL..."
wait_for_postgreSQL.sh

echo "Running Keystone setup..."
keystone-setup.sh

echo "Starting Apache (Keystone WSGI)..."

exec /usr/sbin/apachectl -D FOREGROUND
