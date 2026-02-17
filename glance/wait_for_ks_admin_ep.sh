#!/usr/bin/env bash
set -euo pipefail

: "${WAIT_LOOPS:=30}"
: "${WAIT_SLEEP:=2}"

echo "Waiting for Keystone endpoints..."

for ((i=1; i<=WAIT_LOOPS; i++)); do

    count=$(openstack endpoint list \
        --service identity \
        -f value -c Interface 2>/dev/null | wc -l || true)

    if [[ "$count" -eq 3 ]]; then
        echo "Keystone endpoints ready."
        exit 0
    fi

    echo "[$i/$WAIT_LOOPS] Keystone endpoints not ready yet..."
    sleep "$WAIT_SLEEP"
done

echo "ERROR: Keystone endpoints were not created in time."
exit 1
