FROM openstack-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y openssl

ENV ADMIN_TOKEN=c2905bc8ce0fgfgf7a9cf066a

RUN apt install -y keystone
RUN apt install -y memcached python3-memcache

ADD wait_for_mysql.sh wait_for_mysql.sh
ADD setup.sh setup.sh
ADD run.sh run.sh

RUN chmod +x wait_for_mysql.sh && chmod +x setup.sh && chmod +x run.sh

EXPOSE 5000
EXPOSE 11211

CMD ./wait_for_mysql.sh && ./setup.sh && ./run.sh
