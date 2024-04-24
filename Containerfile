FROM docker.io/library/debian:bookworm-slim

ARG DEBIAN_FRONTEND=noninteractive

RUN \
	set -e; \
	apt update; \
	apt install -y --no-install-recommends \
  autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev \
  python3 python3-pip net-tools zlib1g-dev libsodium-dev gettext \
  libevent-dev wget python3-poetry pkg-config libpq-dev python3-dev \ 
  libffi-dev

ADD volume/scripts/build.sh /static/scripts/build.sh

RUN \
	set -e; \
	/static/scripts/build.sh

FROM docker.io/library/debian:bookworm-slim

RUN \
	set -e; \
	apt update; \
	apt install -y --no-install-recommends \
		libtool libgmp-dev libsqlite3-dev zlib1g-dev libsodium-dev \
		libevent-dev libpq-dev libffi-dev \
		tor

ENV PATH=/volume/data:/lightning/lightningd:/lightning/cli:${PATH}

COPY --from=0 /lightning/cli/lightning-cli /lightning/cli/lightning-cli
COPY --from=0 /lightning/lightningd/lightningd /lightning/lightningd/lightningd
COPY --from=0 /lightning/tools/hsmtool /lightning/tools/hsmtool

COPY --from=0 \
	/lightning/lightningd/lightning_channeld \
	/lightning/lightningd/lightning_closingd \
	/lightning/lightningd/lightning_connectd \
	/lightning/lightningd/lightning_dualopend \
	/lightning/lightningd/lightning_gossipd \
	/lightning/lightningd/lightning_hsmd \
	/lightning/lightningd/lightning_onchaind \
	/lightning/lightningd/lightning_openingd \
	/lightning/lightningd/lightning_websocketd \
	/lightning/lightningd/

COPY --from=0 \
	/lightning/plugins/autoclean \
	/lightning/plugins/bcli \
	/lightning/plugins/fetchinvoice \
	/lightning/plugins/funder \
	/lightning/plugins/topology \
	/lightning/plugins/keysend \
	/lightning/plugins/offers \
	/lightning/plugins/pay \
	/lightning/plugins/txprepare \
	/lightning/plugins/spenderp \
	/lightning/plugins/

ENTRYPOINT ["/volume/scripts/init.sh"]
