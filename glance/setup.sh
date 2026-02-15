#! /bin/bash

if [ -f /setup.done ];
then
   echo "Setup done" > /tmp/done
   exit 0
fi

echo "CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY '$GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY '$GLANCE_DBPASS';
FLUSH PRIVILEGES;" | mysql --user=root --password=$MYSQL_ROOT_PASSWORD -h $MYSQLHOST -P 3306

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

source /admin-openrc.sh

./wait_for_ks_admin_ep.sh

openstack user create --domain default --password $GLANCE_PASS glance

openstack role add --project service --user glance admin

openstack service create --name glance \
  --description "OpenStack Image service" image

openstack endpoint create --region $REGION1 \
  image public http://$GLANCE_HOST:9292

# Required, maybe my VM is too slow ; TODO make a loop on rc != 0
sleep 5
openstack endpoint create --region $REGION1 \
  image internal http://$GLANCE_HOST:9292

# Required, maybe my VM is too slow ; TODO make a loop on rc != 0
sleep 5
openstack endpoint create --region $REGION1 \
  image admin http://$GLANCE_HOST:9292

openstack role add --user glance --user-domain Default --system all reader

ENDPOINT_ID=`openstack endpoint list --service glance --region RegionOne | grep RegionOne | grep public | cut -f 2 -d ' '`


cp /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak
crudini --set /etc/glance/glance-api.conf database connection mysql+pymysql://glance:$GLANCE_DBPASS@$MYSQLHOST/glance

crudini --set /etc/glance/glance-api.conf keystone_authtoken www_authenticate_uri http://$KEYSTONE_HOST:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_url http://$KEYSTONE_HOST:5000
crudini --set /etc/glance/glance-api.conf keystone_authtoken memcached_servers $KEYSTONE_HOST:11211

crudini --set /etc/glance/glance-api.conf keystone_authtoken auth_type password
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken user_domain_name Default
crudini --set /etc/glance/glance-api.conf keystone_authtoken project_name service
crudini --set /etc/glance/glance-api.conf keystone_authtoken username glance
crudini --set /etc/glance/glance-api.conf keystone_authtoken password $GLANCE_PASS

crudini --set /etc/glance/glance-api.conf paste_deploy flavor keystone

crudini --set /etc/glance/glance-api.conf DEFAULT enabled_backends fs:file

crudini --set /etc/glance/glance-api.conf glance_store default_backend fs

crudini --set /etc/glance/glance-api.conf fs filesystem_store_datadir /var/lib/glance/images/

crudini --set /etc/glance/glance-api.conf oslo_limit auth_url http://$KEYSTONE_HOST:5000
crudini --set /etc/glance/glance-api.conf oslo_limit auth_type password
crudini --set /etc/glance/glance-api.conf oslo_limit user_domain_id default
crudini --set /etc/glance/glance-api.conf oslo_limit username glance
crudini --set /etc/glance/glance-api.conf oslo_limit system_scope all
crudini --set /etc/glance/glance-api.conf oslo_limit password $GLANCE_PASS
crudini --set /etc/glance/glance-api.conf oslo_limit endpoint_id $ENDPOINT_ID
crudini --set /etc/glance/glance-api.conf oslo_limit region_name $REGION1

diff /etc/glance/glance-api.conf /etc/glance/glance-api.conf.bak

sleep 5

su -s /bin/sh -c "glance-manage db_sync" glance 2>&1 > /var/log/glance/glance-manage.out
service glance-api restart

touch /setup.done
