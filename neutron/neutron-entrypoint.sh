#!/usr/bin/env bash
set -euo pipefail

echo "Starting Neutron container..."

echo "Running Neutron setup..."
neutron-setup.sh

echo "Starting neutron..."

exec neutron-server
#exec tail -F /var/log/log.log

