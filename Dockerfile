ARG STELLAR_CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF
ARG STELLAR_RPC_IMAGE_REF

FROM $STELLAR_CORE_IMAGE_REF AS stellar-core
FROM $HORIZON_IMAGE_REF AS horizon
FROM $STELLAR_RPC_IMAGE_REF AS stellar-rpc

FROM ubuntu:24.04

EXPOSE 5432
EXPOSE 6061
EXPOSE 8000
EXPOSE 8003
EXPOSE 11826
EXPOSE 31402

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

COPY --from=stellar-core /usr/local/bin/stellar-core /usr/bin/stellar-core
COPY --from=horizon /go/bin/horizon /usr/bin/stellar-horizon
COPY --from=stellar-rpc /usr/local/bin/stellar-rpc /usr/bin/stellar-rpc

# UID 1500: 999 conflicts with a system group created by apt on Ubuntu 24.04 noble.
RUN adduser --system --group --quiet --uid 1500 --home /var/lib/stellar --disabled-password --shell /bin/bash stellar

RUN ["mkdir", "-p", "/opt/stellar"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
RUN ["ln", "-s", "/opt/stellar/stellar-rpc/etc/stellar-rpc.cfg", "/stellar-rpc.cfg"]
ADD common /opt/stellar-default/common
ADD mainnet /opt/stellar-default/mainnet

ADD migrations /migrations
RUN chmod +x /migrations/*.sh

ADD node-status/node-status.sh /usr/local/bin/node-status
RUN ["chmod", "+x", "/usr/local/bin/node-status"]

ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
