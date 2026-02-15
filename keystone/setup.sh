#! /bin/bash

if [ -f /setup.done ];
then
   echo "Setup done" > /tmp/done
   exit 0
fi

## Set up keystone
echo "CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY '$KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY '$KEYSTONE_DBPASS';
FLUSH PRIVILEGES;" | mysql --user=root --password=$MYSQL_ROOT_PASSWORD -h $MYSQLHOST -P 3306

cp /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak
crudini --set /etc/keystone/keystone.conf database connection mysql+pymysql://keystone:$KEYSTONE_DBPASS@$MYSQLHOST/keystone
crudini --set /etc/keystone/keystone.conf token provider fernet
diff /etc/keystone/keystone.conf /etc/keystone/keystone.conf.bak

sleep 5

su -s /bin/sh -c "keystone-manage db_sync" keystone 2>&1 > /var/log/keystone/keystone-manage.out

keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

keystone-manage bootstrap --bootstrap-password $ADMIN_PASS \
--bootstrap-admin-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-internal-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-public-url http://$KEYSTONE_HOST:5000/v3/ \
--bootstrap-region-id $REGION1

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

openstack domain create --description "An Example Domain" example

openstack project create --domain default --description "Service Project" service

openstack project create --domain default --description "Demo Project" user-project
openstack user create --domain default --password $DEMO_PASS user-demo
openstack role create user-role
openstack role add --project user-project --user user-demo user-role

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
