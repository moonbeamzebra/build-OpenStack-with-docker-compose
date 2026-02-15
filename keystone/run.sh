#! /bin/bash +ex
memcached -u memcache & 
#service memcache restart
service apache2 restart
touch /var/log/apache2/keystone_access.log
tail -F /var/log/apache2/keystone_access.log
#memcached -u memcache & 
#/usr/sbin/apache2ctl -D FOREGROUND

