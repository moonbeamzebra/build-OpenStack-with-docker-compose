FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
        crudini \
        curl \
        netcat-openbsd \
        mariadb-client \
        python3-mysqldb



## Get the packages
RUN apt-get install software-properties-common -y
RUN add-apt-repository cloud-archive:dalmatian -y
RUN apt-get update -y

RUN apt-get install -y python3-openstackclient

## TODO remove vim net-tools iputils-ping after everything works well
RUN apt-get install -y vim net-tools iputils-ping

