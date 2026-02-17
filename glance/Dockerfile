FROM openstack-base

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get install -y glance

ADD setup.sh setup.sh
ADD run.sh run.sh
ADD wait_for_ks_admin_ep.sh wait_for_ks_admin_ep.sh
ADD wait_for_postgreSQL.sh wait_for_postgreSQL.sh

RUN chmod +x wait_for_ks_admin_ep.sh && chmod +x wait_for_postgreSQL.sh && chmod +x run.sh && chmod +x setup.sh

EXPOSE 9292

CMD ./wait_for_postgreSQL.sh && ./setup.sh && sleep 5 && ./run.sh
#CMD tail -F /var/log/glance.log
