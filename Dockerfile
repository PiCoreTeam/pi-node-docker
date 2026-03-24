ARG STELLAR_CORE_IMAGE_REF
ARG HORIZON_IMAGE_REF

FROM $STELLAR_CORE_IMAGE_REF AS stellar-core
FROM $HORIZON_IMAGE_REF AS horizon

FROM ubuntu:20.04

EXPOSE 5432
EXPOSE 8000
EXPOSE 31402

ADD dependencies /
RUN ["chmod", "+x", "dependencies"]
RUN /dependencies

COPY --from=stellar-core /usr/local/bin/stellar-core /usr/bin/stellar-core
COPY --from=horizon /go/bin/horizon /usr/bin/stellar-horizon

RUN adduser --system --group --quiet --home /var/lib/stellar --disabled-password --shell /bin/bash stellar

RUN ["mkdir", "-p", "/opt/stellar"]

RUN ["ln", "-s", "/opt/stellar", "/stellar"]
RUN ["ln", "-s", "/opt/stellar/core/etc/stellar-core.cfg", "/stellar-core.cfg"]
RUN ["ln", "-s", "/opt/stellar/horizon/etc/horizon.env", "/horizon.env"]
ADD common /opt/stellar-default/common
ADD mainnet /opt/stellar-default/mainnet
ADD testnet /opt/stellar-default/testnet
ADD testnet2 /opt/stellar-default/testnet2

ADD migrations /migrations
RUN chmod +x /migrations/*.sh

ADD start /
RUN ["chmod", "+x", "start"]

ENTRYPOINT ["/start"]
