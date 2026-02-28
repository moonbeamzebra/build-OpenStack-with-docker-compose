#!/usr/bin/env bash
set -euo pipefail

echo "Starting Nova container..."

echo "Running Nova setup..."
nova-setup.sh

echo "Starting nova-api..."

exec nova-api

