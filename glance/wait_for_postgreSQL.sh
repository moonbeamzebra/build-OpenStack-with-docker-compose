#!/usr/bin/env bash
set -euo pipefail

########################################
# Defaults (override via env vars)
########################################

: "${WAIT_LOOPS:=60}"
: "${WAIT_SLEEP:=2}"
: "${MYPOSTGRESQLHOST:?MYPOSTGRESQLHOST not set}"
: "${POSTGRES_PORT:=5432}"
: "${POSTGRES_USER:=postgres}"

########################################
# Check pg_isready availability
########################################

if ! command -v pg_isready >/dev/null 2>&1; then
    echo "ERROR: pg_isready command not found."
    echo "Install postgresql-client package."
    exit 1
fi

########################################
# Wait loop (network + server ready)
########################################

echo "Waiting for PostgreSQL on ${MYPOSTGRESQLHOST}:${POSTGRES_PORT} ..."

for ((i=1; i<=WAIT_LOOPS; i++)); do

    if pg_isready \
        --host="$MYPOSTGRESQLHOST" \
        --port="$POSTGRES_PORT" \
        --username="$POSTGRES_USER" \
        >/dev/null 2>&1; then

        echo "PostgreSQL is accepting connections."
        break
    fi

    echo "[$i/$WAIT_LOOPS] PostgreSQL not ready yet..."
    sleep "$WAIT_SLEEP"

    if [[ "$i" -eq "$WAIT_LOOPS" ]]; then
        echo "ERROR: PostgreSQL did not become ready in time."
        exit 1
    fi
done

########################################
# Optional: verify authentication works
########################################

if [[ -n "${POSTGRES_ROOT_PASSWORD:-}" ]]; then
    export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

    echo "Verifying PostgreSQL authentication..."

    if ! psql \
        --host="$MYPOSTGRESQLHOST" \
        --port="$POSTGRES_PORT" \
        --username="$POSTGRES_USER" \
        --dbname=postgres \
        --no-password \
        --command="SELECT 1;" \
        >/dev/null 2>&1; then

        echo "ERROR: PostgreSQL reachable but authentication failed."
        exit 1
    fi

    echo "PostgreSQL authentication successful."
fi

echo "PostgreSQL is fully ready."
exit 0
