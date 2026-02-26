#! /bin/bash

cd /home/lab/git/build-OpenStack-with-docker-compose
docker compose rm -s -f
sudo rm -rf /var/lib/openstack-mariadb
sudo rm -rf /var/lib/openstack-postgres
sudo rm -rf /var/lib/openstack-rabbitmq

docker rmi  build-openstack-with-docker-compose-keystone:latest \
            build-openstack-with-docker-compose-keystone-init:latest \
            build-openstack-with-docker-compose-glance:latest \
            build-openstack-with-docker-compose-placement:latest \
            openstack-base:latest

#docker build -t openstack-base openstack-base
docker build --build-arg DEBUG=true -t openstack-base openstack-base

docker compose create
docker compose start

