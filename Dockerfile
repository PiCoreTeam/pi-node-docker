FROM ubuntu:20.04

ENV STELLAR_CORE_VERSION 19.9.0-1254.064a2787a.focal
ENV HORIZON_VERSION 2.30.0-436

EXPOSE 5432
EXPOSE 8000
EXPOSE 31402

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

ADD install /
RUN ["chmod", "+x", "install"]
RUN /install

RUN ["mkdir", "-p", "/opt/stellar"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
ADD common /opt/stellar-default/common
ADD pubnet /opt/stellar-default/pubnet
ADD testnet /opt/stellar-default/testnet
ADD testnet2 /opt/stellar-default/testnet2

ADD mirror_full_archive.sh /
ADD horizon_complete_reingest.sh /

RUN ["chmod", "+x", "/mirror_full_archive.sh"]
RUN ["chmod", "+x", "/horizon_complete_reingest.sh"]

ADD migrations /migrations
RUN chmod +x /migrations/*.sh

ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
