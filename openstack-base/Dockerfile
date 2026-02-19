FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

# Install base system dependencies + OpenStack repo in one layer
RUN apt-get update \
 && apt-get install -y --no-install-recommends \
        software-properties-common \
        ca-certificates \
        curl \
        netcat-openbsd \
        postgresql-client \
        python3-psycopg2 \
        libpq-dev \
        crudini \
 && add-apt-repository -y cloud-archive:dalmatian \
 && apt-get update \
 && apt-get install -y --no-install-recommends \
        python3-openstackclient \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists/*

 ARG DEBUG=false
 RUN if [ "$DEBUG" = "true" ]; then \
       apt-get update \
       && apt-get install -y --no-install-recommends vim iputils-ping net-tools \
       && apt-get clean \
       && rm -rf /var/lib/apt/lists/* ; \
     fi

