#! /bin/bash +ex

service glance-api restart

tail -F /var/log/glance.log
