#!/usr/bin/env bash
set -euo pipefail

echo "Starting Placement container..."

echo "Running Placement setup..."
placement-setup.sh

echo "Starting placement-api..."

exec gunicorn3 --bind 0.0.0.0:8778 --workers 4 --threads 2 "placement.wsgi:init_application()"

