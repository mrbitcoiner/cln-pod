FROM docker.io/library/debian:bookworm-slim
ARG DEBIAN_FRONTEND=noninteractive
RUN \
	set -e; \
	apt update; \
	apt install -y --no-install-recommends \
  autoconf automake build-essential git libtool libgmp-dev libsqlite3-dev \
  python3 python3-pip net-tools zlib1g-dev libsodium-dev gettext \
  libevent-dev wget python3.11-venv pkg-config libpq-dev python3-dev \ 
  libffi-dev jq
ENV CLN_REPO='https://github.com/elementsproject/lightning'
# v24.11.1
ENV COMMIT_VERSION='e6398e5b9aa1d54b42fc61db2ac35558f8e4f38a' 
RUN \
	set -e; \
	git clone ${CLN_REPO} /lightning \
	&& cd /lightning \
	&& git checkout ${COMMIT_VERSION} \
	&& export VENV_PATH='tmp_venv' \
	&& python3 -m venv ${VENV_PATH} \
	&& ${VENV_PATH}/bin/pip install -U pip setuptools \
	&& ${VENV_PATH}/bin/pip install poetry \
	&& export POETRY=${VENV_PATH}/bin/poetry \
	&& ${POETRY} install || true \
	&& ${POETRY} run ./configure \
	&& ${POETRY} run make -j 4 \
	&& mkdir /lightning_out \
	&& mkdir -p /lightning_out/cli \
	&& mkdir -p /lightning_out/lightningd \
	&& mkdir -p /lightning_out/tools \
	&& mkdir -p /lightning_out/plugins \
	&& mkdir -p /lightning_out/plugins/clnrest \
	&& mkdir -p /lightning_out/plugins/wss-proxy \
	&& cp -a cli/lightning-cli /lightning_out/cli/lightning-cli \
	&& cp -a tools/hsmtool /lightning_out/tools/hsmtool \
	&& cd lightningd \
	&& cp -a \
		lightningd lightning_channeld lightning_closingd lightning_connectd \
		lightning_dualopend lightning_gossipd lightning_hsmd lightning_onchaind \
		lightning_openingd lightning_websocketd \
		/lightning_out/lightningd/ \
	&& cd ../plugins \
	&& cp -a \
		autoclean bcli funder topology keysend offers pay txprepare spenderp \
		chanbackup commando exposesecret recklessrpc recover cln-renepay cln-xpay \
		cln-askrene sql bookkeeper \
		/lightning_out/plugins/ \
	&& cp -a clnrest/clnrest /lightning_out/plugins/clnrest/clnrest	 \
	&& cp -a wss-proxy/wss-proxy /lightning_out/plugins/wss-proxy/wss-proxy \
	&& rm -rf /lightning \
	&& mv /lightning_out /lightning
FROM docker.io/library/debian:bookworm-slim
RUN \
	set -e; \
	apt update; \
	apt install -y --no-install-recommends \
		libtool libgmp-dev libsqlite3-dev zlib1g-dev libsodium-dev \
		libevent-dev libpq-dev libffi-dev \
		tor
ENV PATH=/volume/data:/lightning/lightningd:/lightning/cli:${PATH}
COPY --from=0 /lightning /lightning
ENTRYPOINT ["/volume/scripts/init.sh"]
