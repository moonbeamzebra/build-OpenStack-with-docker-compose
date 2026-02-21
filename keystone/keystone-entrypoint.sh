#!/usr/bin/env bash
set -euo pipefail

echo "Running Keystone setup..."
keystone-setup.sh

echo "Starting Apache (Keystone WSGI)..."

exec /usr/sbin/apachectl -D FOREGROUND
