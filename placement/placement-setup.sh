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


echo "Creating placement database..."
########################################
# PostgreSQL setup (idempotent)
########################################
## export PGPASSWORD=$POSTGRES_ROOT_PASSWORD; psql -U postgres -d postgres -h postgres -p 5432
## export PGPASSWORD=$PLACEMENT_DBPASS; psql -U placement -d placement -h postgres -p 5432

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE USER placement WITH PASSWORD '$PLACEMENT_DBPASS';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_roles WHERE rolname='placement'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE USER placement WITH PASSWORD '$PLACEMENT_DBPASS';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE USER placement WITH PASSWORD '$PLACEMENT_DBPASS';\""

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE DATABASE placement OWNER placement ENCODING 'UTF8';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_database WHERE datname='placement'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE DATABASE placement OWNER placement ENCODING 'UTF8';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE DATABASE placement OWNER placement ENCODING 'UTF8';\""

cp --update=none /etc/placement/placement.conf /etc/placement/placement.conf.bak || true

#crudini --set /etc/placement/placement.conf DEFAULT debug true
crudini --set /etc/placement/placement.conf DEFAULT debug false

crudini --set /etc/placement/placement.conf api auth_strategy keystone

crudini --set /etc/placement/placement.conf placement_database connection postgresql+psycopg2://placement:${PLACEMENT_DBPASS}@postgres/placement

crudini --set /etc/placement/placement.conf keystone_authtoken www_authenticate_uri http://keystone:5000
crudini --set /etc/placement/placement.conf keystone_authtoken auth_url http://keystone:5000
crudini --set /etc/placement/placement.conf keystone_authtoken memcached_servers memcached:11211
crudini --set /etc/placement/placement.conf keystone_authtoken auth_type password
crudini --set /etc/placement/placement.conf keystone_authtoken project_domain_name Default
crudini --set /etc/placement/placement.conf keystone_authtoken user_domain_name Default
crudini --set /etc/placement/placement.conf keystone_authtoken project_name service
crudini --set /etc/placement/placement.conf keystone_authtoken username placement
crudini --set /etc/placement/placement.conf keystone_authtoken password ${PLACEMENT_PASS}

crudini --set /etc/placement/placement.conf oslo_concurrency passlock_pathword /var/lib/placement/tmp

diff /etc/placement/placement.conf /etc/placement/placement.conf.bak || true


echo "Syncing placement DB..."
placement-manage db sync

echo "Creating placement user in Keystone..."

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

echo "DO openstack user create --domain Default --password "$PLACEMENT_PASS" placement"
retry 10 0 1 -- openstack user show --domain Default placement >/dev/null 2>&1 || \
retry 10 0 -- openstack user create --domain Default --password "$PLACEMENT_PASS" placement
echo "DONE RC=$? ;openstack user create --domain Default --password "$PLACEMENT_PASS" placement"

echo "DO openstack role add --project service --user placement admin"
retry 10 0 1 -- openstack role assignment list --user placement --project service -f value --names | grep -q admin || \
retry 10 0 -- openstack role add --project service --user placement admin
echo "DONE RC=$? ;openstack role add --project service --user placement admin"

echo "DO openstack service create --name placement --description "OpenStack Image service" placement"
retry 10 0 1 -- openstack service show placement >/dev/null 2>&1 || \
retry 10 0 -- openstack service create --name placement --description "Placement API" placement
echo "DONE RC=$? ;openstack service create --name placement --description "OpenStack Image service" placement"

for iface in public internal admin; do
    echo "DO openstack endpoint create --region "$REGION1" placement "$iface" http://placement:8778"
    retry 10 0 1 -- openstack endpoint list --service placement --interface "$iface" --region "$REGION1" -f value -c URL | grep -q http://placement:8778 || \
    retry 10 0 -- openstack endpoint create --region "$REGION1" placement "$iface" http://placement:8778
    echo "DONE RC=$? ;openstack endpoint create --region "$REGION1" placement "$iface" http://placement:8778"
done

touch /setup.done

echo "Placement setup.sh completed successfully."
