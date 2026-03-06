#!/usr/bin/env bash
set -euo pipefail

. /admin-openrc.sh
export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"
psql -U postgres -h "postgres" -tc "SELECT * FROM pg_roles WHERE rolname='neutron'"
psql -U postgres -h "postgres" -tc "SELECT * FROM pg_database WHERE datname='neutron'"

openstack user show --domain default neutron
openstack role assignment list --user neutron --project service -f value --names
openstack role assignment list --user neutron --project service  --names
openstack service show network
openstack endpoint list --service network
openstack catalog list
