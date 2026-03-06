#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -f /setup.done ]]; then
    echo "Setup already completed."
    exit 0
fi

########################################
# Helpers
########################################

########################################
# retry compatible set -e
########################################
retry() {
    local retries="$1"
    shift

    local no_retry_codes=()

    while [[ "$1" != "--" ]]; do
        no_retry_codes+=("$1")
        shift
    done
    shift

    [[ ${#no_retry_codes[@]} -eq 0 ]] && no_retry_codes=(0)

    local count=0
    local rc

    while true; do
        set +e
        "$@"
        rc=$?
        for code in "${no_retry_codes[@]}"; do
            [[ $rc -eq $code ]] && set -e && return $rc
        done

        ((count++))
        if ((count >= retries)); then
            echo "Command failed after $count attempts (rc=$rc)"
            return "$rc"
        fi

        echo "====="
        echo "RETRY: [$@] $count/$retries (rc=$rc) ... in 3 seconds"
        echo "====="
        sleep 3
    done
}


echo "Creating neutron database..."
########################################
# PostgreSQL setup (idempotent)
########################################
## export PGPASSWORD=$POSTGRES_ROOT_PASSWORD; psql -U postgres -d postgres -h postgres -p 5432
## export PGPASSWORD=$NEUTRON_DBPASS; psql -U neutron -d neutron -h postgres -p 5432

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

# Create user neutron
echo "DO psql -U postgres -h \"postgres\" -c \"CREATE USER neutron WITH PASSWORD '$NEUTRON_DBPASS';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_roles WHERE rolname='neutron'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE USER neutron WITH PASSWORD '$NEUTRON_DBPASS';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE USER neutron WITH PASSWORD '$NEUTRON_DBPASS';\""

# DATABASE neutron
echo "DO psql -U postgres -h \"postgres\" -c \"CREATE DATABASE neutron OWNER neutron ENCODING 'UTF8';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_database WHERE datname='neutron'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE DATABASE neutron OWNER neutron ENCODING 'UTF8';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE DATABASE neutron OWNER neutron ENCODING 'UTF8';\""

cat >/admin-openrc.sh <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://keystone:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat >/demo-openrc.sh <<EOF
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=user-project
export OS_USERNAME=user-demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://keystone:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

source /admin-openrc.sh

echo "DO openstack user create --domain default --password "$NEUTRON_PASS" neutron"
retry 10 0 1 -- openstack user show --domain default neutron >/dev/null 2>&1 || \
retry 10 0 -- openstack user create --domain default --password "$NEUTRON_PASS" neutron
echo "DONE RC=$? ;openstack user create --domain default --password "$NEUTRON_PASS" neutron"

echo "DO openstack role add --project service --user neutron admin"
retry 10 0 1 -- openstack role assignment list --user neutron --project service -f value --names | grep -q admin || \
retry 10 0 -- openstack role add --project service --user neutron admin
echo "DONE RC=$? ;openstack role add --project service --user neutron admin"

echo "DO openstack service create --name neutron --description "OpenStack Networking" network"
retry 10 0 1 -- openstack service show network >/dev/null 2>&1 || \
retry 10 0 -- openstack service create --name neutron --description "OpenStack Networking" network
echo "DONE RC=$? ;openstack service create --name neutron --description "OpenStack Networking" network"

for iface in public internal admin; do
    echo "DO openstack endpoint create --region "$REGION1" network "$iface" http://neutron:9696"
    retry 10 0 1 -- openstack endpoint list --service network --interface "$iface" --region "$REGION1" -f value -c URL | grep -q http://neutron:9696 || \
    retry 10 0 -- openstack endpoint create --region "$REGION1" network "$iface" http://neutron:9696
    echo "DONE RC=$? ;openstack endpoint create --region "$REGION1" network "$iface" http://neutron:9696"
done

echo "Populate the neutron database..."
su -s /bin/sh -c "neutron-db-manage \
  --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
  upgrade head" neutron

touch /setup.done

echo "Neutron setup.sh completed successfully."
