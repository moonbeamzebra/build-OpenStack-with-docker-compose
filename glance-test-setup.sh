#!/usr/bin/env bash
set -euo pipefail

export PGPASSWORD="$POSTGRES_ROOT_PASSWORD"
psql -U postgres -h "$MYPOSTGRESQLHOST" -tc "SELECT * FROM pg_roles WHERE rolname='glance'"
psql -U postgres -h "$MYPOSTGRESQLHOST" -tc "SELECT * FROM pg_database WHERE datname='glance'"

openstack user show --domain default glance
openstack role assignment list --user glance --project service -f value --names
openstack role assignment list --user glance --system all -f value --names
openstack service show glance

for iface in public internal admin; do
    openstack endpoint list --service glance --interface "$iface" --region "$REGION1" -f value -c URL
done

ENDPOINT_ID=$(openstack endpoint list --service glance --interface public --region "$REGION1" -f value -c ID)
echo "ENDPOINT_ID=[${ENDPOINT_ID}]"

diff /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak || true

export PGPASSWORD="$GLANCE_DBPASS"
psql -U glance -d glance -h $MYPOSTGRESQLHOST -p 5432 -tc "\dt"

curl -O http://download.cirros-cloud.net/0.4.0/cirros-0.4.0-x86_64-disk.img
glance image-create --name "cirros" \
  --file cirros-0.4.0-x86_64-disk.img \
  --disk-format qcow2 --container-format bare \
  --visibility=public || true

psql -U glance -d glance -h $MYPOSTGRESQLHOST -p 5432 -tc "SELECT * FROM images"


