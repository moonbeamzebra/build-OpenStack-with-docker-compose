#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

if [[ -f /setup.done ]]; then
    echo "Setup already completed."
    exit 0
fi

########################################
# PostgreSQL setup (idempotent)
########################################
## export PGPASSWORD=$POSTGRES_ROOT_PASSWORD; psql -U postgres -d postgres -h postgres -p 5432
## export PGPASSWORD=$KEYSTONE_DBPASS; psql -U keystone -d keystone -h postgres -p 5432

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_roles WHERE rolname='keystone'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE USER keystone WITH PASSWORD '$KEYSTONE_DBPASS';\""

echo "DO psql -U postgres -h \"postgres\" -c \"CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';\""
psql -U postgres -h "postgres" -tc "SELECT 1 FROM pg_database WHERE datname='keystone'" | grep -q 1 || \
psql -U postgres -h "postgres" -c "CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';"
echo "DONE RC=$? ;psql -U postgres -h \"postgres\" -c \"CREATE DATABASE keystone OWNER keystone ENCODING 'UTF8';\""

cp --update=none /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak || true

crudini --set /etc/keystone/keystone.conf database connection postgresql+psycopg2://keystone:$KEYSTONE_DBPASS@postgres/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet

crudini --set /etc/keystone/keystone.conf cache backend oslo_cache.memcache_pool
crudini --set /etc/keystone/keystone.conf cache enabled true
crudini --set /etc/keystone/keystone.conf cache memcache_servers memcached:11211

diff /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak || true

su -s /bin/sh -c "keystone-manage db_sync" keystone

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
--bootstrap-admin-url http://keystone:5000/v3/ \
--bootstrap-internal-url http://keystone:5000/v3/ \
--bootstrap-public-url http://keystone:5000/v3/ \
--bootstrap-region-id $REGION1

grep -q "ServerName keystone" /etc/apache2/apache2.conf || \
echo "ServerName keystone" >> /etc/apache2/apache2.conf

cat <<EOF > /admin-openrc.sh
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=$ADMIN_PASS
export OS_AUTH_URL=http://keystone:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

cat <<EOF > /demo-openrc.sh
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=user-project
export OS_USERNAME=user-demo
export OS_PASSWORD=$DEMO_PASS
export OS_AUTH_URL=http://keystone:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
EOF

touch /setup.done

echo "Keystone setup.sh finish successfully"

