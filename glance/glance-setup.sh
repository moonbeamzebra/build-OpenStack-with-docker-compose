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

########################################
# PostgreSQL setup (idempotent)
########################################
## export PGPASSWORD=$POSTGRES_ROOT_PASSWORD; psql -U postgres -d postgres -h postgres -p 5432
## export PGPASSWORD=$GLANCE_DBPASS; psql -U glance -d glance -h postgres -p 5432

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE USER glance WITH PASSWORD '$GLANCE_DBPASS';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_roles WHERE rolname='glance'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE USER glance WITH PASSWORD '$GLANCE_DBPASS';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE USER glance WITH PASSWORD '$GLANCE_DBPASS';\""

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE DATABASE glance OWNER glance ENCODING 'UTF8';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_database WHERE datname='glance'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE DATABASE glance OWNER glance ENCODING 'UTF8';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE DATABASE glance OWNER glance ENCODING 'UTF8';\""

########################################
# OpenStack Admin context
########################################

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

########################################
# Wait Keystone
########################################

/usr/local/bin/wait_for_ks_admin_ep.sh

########################################
# Glance user / role (idempotent)
########################################

echo "DO openstack user create --domain default --password "$GLANCE_PASS" glance"
retry 10 0 1 -- openstack user show --domain default glance >/dev/null 2>&1 || \
retry 10 0 -- openstack user create --domain default --password "$GLANCE_PASS" glance
echo "DONE RC=$? ;openstack user create --domain default --password "$GLANCE_PASS" glance"

echo "DO openstack role add --project service --user glance admin"
retry 10 0 1 -- openstack role assignment list --user glance --project service -f value --names | grep -q admin || \
retry 10 0 -- openstack role add --project service --user glance admin
echo "DONE RC=$? ;openstack role add --project service --user glance admin"

echo "DO openstack role add --user glance --system all reader"
retry 10 0 1 -- openstack role assignment list --user glance --system all -f value --names | grep -q reader || \
retry 10 0 -- openstack role add --user glance --system all reader
echo "DONE RC=$? ;openstack role add --user glance --system all reader"

########################################
# Service + endpoints
########################################

echo "DO openstack service create --name glance --description "OpenStack Image service" image"
retry 10 0 1 -- openstack service show glance >/dev/null 2>&1 || \
retry 10 0 -- openstack service create --name glance --description "OpenStack Image service" image
echo "DONE RC=$? ;openstack service create --name glance --description "OpenStack Image service" image"

for iface in public internal admin; do
    echo "DO openstack endpoint create --region "$REGION1" image "$iface" http://glance:9292"
    retry 10 0 1 -- openstack endpoint list --service glance --interface "$iface" --region "$REGION1" -f value -c URL | grep -q http://glance:9292 || \
    retry 10 0 -- openstack endpoint create --region "$REGION1" image "$iface" http://glance:9292
    echo "DONE RC=$? ;openstack endpoint create --region "$REGION1" image "$iface" http://glance:9292"
done

########################################
# Get endpoint_id safely
########################################

echo "DO ENDPOINT_ID=\$(retry 10 0 -- openstack endpoint list --service glance --interface public --region "$REGION1" -f value -c ID)"
ENDPOINT_ID=$(retry 10 0 -- openstack endpoint list --service glance --interface public --region "$REGION1" -f value -c ID)
echo "DONE RC=$? ;ENDPOINT_ID=\$(retry 10 0 -- openstack endpoint list --service glance --interface public --region "$REGION1" -f value -c ID)"

########################################
# Configure glance-api.conf
########################################

cp --update=none /etc/glance/glance-api.conf \
      /etc/glance/glance-api.conf.bak || true

crudini --set /etc/glance/glance-api.conf database connection \
postgresql+psycopg2://glance:$GLANCE_DBPASS@postgres/glance

crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://keystone:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://keystone:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers memcached:11211
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password "$GLANCE_PASS"

crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

crudini --set /etc/glance/glance-api.conf DEFAULT enabled_backends fs:file
crudini --set /etc/glance/glance-api.conf glance_store default_backend fs
crudini --set /etc/glance/glance-api.conf fs filesystem_store_datadir /var/lib/glance/images/

crudini --set /etc/glance/glance-api.conf oslo_limit auth_url http://keystone:5000
crudini --set /etc/glance/glance-api.conf oslo_limit auth_type password
crudini --set /etc/glance/glance-api.conf oslo_limit user_domain_id default
crudini --set /etc/glance/glance-api.conf oslo_limit username glance
crudini --set /etc/glance/glance-api.conf oslo_limit system_scope all
crudini --set /etc/glance/glance-api.conf oslo_limit password "$GLANCE_PASS"
crudini --set /etc/glance/glance-api.conf oslo_limit endpoint_id "$ENDPOINT_ID"
crudini --set /etc/glance/glance-api.conf oslo_limit region_name "$REGION1"

diff /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak || true

########################################
# DB sync + restart
########################################

su -s /bin/sh -c "glance-manage db_sync" glance

#service glance-api restart

touch /setup.done

echo "Glance setup.sh completed successfully."
