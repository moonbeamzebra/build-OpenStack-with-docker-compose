FROM openstack-base

ENV DEBIAN_FRONTEND=noninteractive

# System packages
RUN apt install -y keystone
RUN apt install -y memcached python3-memcache

# Create logs directory
RUN mkdir -p /var/log/keystone \
    && chown -R keystone:keystone /var/log/keystone

ADD wait_for_postgreSQL.sh wait_for_postgreSQL.sh
ADD wait_for_mysql.sh wait_for_mysql.sh
ADD setup.sh setup.sh
ADD run.sh run.sh

RUN chmod +x wait_for_mysql.sh && chmod +x wait_for_postgreSQL.sh && chmod +x setup.sh && chmod +x run.sh

# Expose API Keystone port
EXPOSE 5000
# Expose memcached port
EXPOSE 11211

#CMD ./run.sh
CMD ./wait_for_postgreSQL.sh && ./setup.sh && ./run.sh
#CMD ["apachectl", "-D", "FOREGROUND"]