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
## export PGPASSWORD=$POSTGRES_ROOT_PASSWORD; psql -U postgres -d postgres -h $MYPOSTGRESQLHOST -p 5432
## export PGPASSWORD=$KEYSTONE_DBPASS; psql -U keystone -d keystone -h $MYPOSTGRESQLHOST -p 5432

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

echo "DO psql -U postgres -h \"$MYPOSTGRESQLHOST\" -c \"CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';\""
psql -U postgres -h "$MYPOSTGRESQLHOST" -tc "SELECT 1 FROM pg_roles WHERE rolname='keystone'" | grep -q 1 || \
psql -U postgres -h "$MYPOSTGRESQLHOST" -c "CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';"
echo "DONE RC=$? ;psql -U postgres -h \"$MYPOSTGRESQLHOST\" -c \"CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';\""

echo "DO psql -U postgres -h \"$MYPOSTGRESQLHOST\" -c \"CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';\""
psql -U postgres -h "$MYPOSTGRESQLHOST" -tc "SELECT 1 FROM pg_database WHERE datname='keystone'" | grep -q 1 || \
psql -U postgres -h "$MYPOSTGRESQLHOST" -c "CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';"
echo "DONE RC=$? ;psql -U postgres -h \"$MYPOSTGRESQLHOST\" -c \"CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';\""

cp --update=none /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak || true
crudini --set /etc/keystone/keystone.conf database connection postgresql+psycopg2://keystone:$KEYSTONE_DBPASS@$MYPOSTGRESQLHOST/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet
diff /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak || true

#sleep 5

su -s /bin/sh -c "keystone-manage db_sync" keystone

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
--bootstrap-admin-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-internal-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-public-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-region-id $REGION1

grep -q "ServerName $KEYSTONE_HOST" /etc/apache2/apache2.conf || \
echo "ServerName $KEYSTONE_HOST" >> /etc/apache2/apache2.conf

service apache2 restart

sleep 5

export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_PROJECT_NAME=admin
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
export OS_AUTH_URL=http://$KEYSTONE_HOST:5000/v3
export OS_IDENTITY_API_VERSION=3

echo "DO openstack domain create --description "An Example Domain" example"
retry 10 0 1 -- openstack domain show example >/dev/null 2>&1 || \
retry 10 0 -- openstack domain create --description "An Example Domain" example
echo "DONE RC=$? ;openstack domain create --description "An Example Domain" example"

echo "DO openstack project create --domain default --description "Service Project" service"
retry 10 0 1 -- openstack project show --domain default service >/dev/null 2>&1 || \
retry 10 0 -- openstack project create --domain default --description "Service Project" service
echo "DONE RC=$? ;openstack project create --domain default --description "Service Project" service"

echo "DO openstack project create --domain default --description "Demo Project" user-project"
retry 10 0 1 -- openstack project show --domain default user-project >/dev/null 2>&1 || \
retry 10 0 -- openstack project create --domain default --description "Demo Project" user-project
echo "DONE RC=$? ;openstack project create --domain default --description "Demo Project" user-project"

echo "DONE openstack user create --domain default --password $DEMO_PASS user-demo"
retry 10 0 1 -- openstack user show --domain default user-demo >/dev/null 2>&1 || \
retry 10 0 -- openstack user create --domain default --password $DEMO_PASS user-demo
echo "DONE RC=$? ;openstack user create --domain default --password $DEMO_PASS user-demo"

echo "DO openstack role create user-role"
retry 10 0 1 -- openstack role show user-role >/dev/null 2>&1 || \
retry 10 0 -- openstack role create user-role
echo "DONE RC=$? ;openstack role create user-role"

echo "DO openstack role add --project user-project --user user-demo user-role"
retry 10 0 1 -- openstack role assignment list --user user-demo --project user-project -f value --names | grep -q user-role || \
retry 10 0 -- openstack role add --project user-project --user user-demo user-role
echo "DONE RC=$? ;openstack role add --project user-project --user user-demo user-role"

cat <<EOF > /admin-openrc.sh
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://$KEYSTONE_HOST:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat <<EOF > /demo-openrc.sh
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=user-project
export OS_USERNAME=user-demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://$KEYSTONE_HOST:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF


touch /setup.done
