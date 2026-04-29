ARG STELLAR_CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF

FROM $STELLAR_CORE_IMAGE_REF AS stellar-core
FROM $HORIZON_IMAGE_REF AS horizon

FROM ubuntu:24.04

EXPOSE 5432
EXPOSE 8000
EXPOSE 31402

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

COPY --from=stellar-core /usr/local/bin/stellar-core /usr/bin/stellar-core
COPY --from=horizon /go/bin/horizon /usr/bin/stellar-horizon

# UID 1500: 999 conflicts with a system group created by apt on Ubuntu 24.04 noble.
RUN adduser --system --group --quiet --uid 1500 --home /var/lib/stellar --disabled-password --shell /bin/bash stellar

ADD install /
RUN ["chmod", "+x", "install"]
RUN /install

RUN ["mkdir", "-p", "/opt/stellar"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
ADD common /opt/stellar-default/common
ADD pubnet /opt/stellar-default/pubnet

ADD mirror_full_archive.sh /
ADD horizon_complete_reingest.sh /

RUN ["chmod", "+x", "/mirror_full_archive.sh"]
RUN ["chmod", "+x", "/horizon_complete_reingest.sh"]

ADD migrations /migrations
RUN chmod +x /migrations/*.sh

ADD node-status/node-status.sh /usr/local/bin/node-status
RUN ["chmod", "+x", "/usr/local/bin/node-status"]

ARG ENABLE_AUTO_MIGRATIONS=true
ENV ENABLE_AUTO_MIGRATIONS=${ENABLE_AUTO_MIGRATIONS}

ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
