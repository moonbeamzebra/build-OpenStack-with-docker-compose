#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"
psql -U postgres -h "postgres" -tc "SELECT * FROM pg_roles WHERE rolname='placement'"
psql -U postgres -h "postgres" -tc "SELECT * FROM pg_database WHERE datname='placement'"

diff /etc/placement/placement.conf /etc/placement/placement.conf.bak || true

openstack user show --domain Default placement
openstack role assignment list --user placement --project service -f value --names
openstack service show placement
for iface in public internal admin; do
  openstack endpoint list --service placement --interface "$iface" --region "$REGION1" -f value -c URL
done

export PGPASSWORD="$PLACEMENT_DBPASS"
psql -U placement -d placement -h postgres -p 5432 -tc "\dt"

openstack resource class list
