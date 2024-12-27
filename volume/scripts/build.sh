#!/usr/bin/env bash
####################
set -e
####################
readonly CLN_REPO='https://github.com/elementsproject/lightning'
readonly COMMIT_VERSION='e6398e5b9aa1d54b42fc61db2ac35558f8e4f38a' # v24.11.1
####################
cln_build() {
	[ -e "/lightning" ] || git clone ${CLN_REPO} /lightning
	cd /lightning
	git checkout ${COMMIT_VERSION}

	export VENV_PATH='tmp_venv'
	python3 -m venv ${VENV_PATH}
	${VENV_PATH}/bin/pip install -U pip setuptools
	${VENV_PATH}/bin/pip install poetry
	export POETRY=${VENV_PATH}/bin/poetry
	${POETRY} install || true

	${POETRY} run ./configure
	${POETRY} run make
}
cln_finalize() {
	cd /lightning

	! [ -e "/lightning_out" ] || rm -r /lightning_out
	mkdir /lightning_out
	mkdir -p /lightning_out/cli
	mkdir -p /lightning_out/lightningd
	mkdir -p /lightning_out/tools
	mkdir -p /lightning_out/plugins
	mkdir -p /lightning_out/plugins/clnrest
	mkdir -p /lightning_out/plugins/wss-proxy
	cp -a cli/lightning-cli /lightning_out/cli/lightning-cli
	cp -a tools/hsmtool /lightning_out/tools/hsmtool
	cd lightningd
	cp -a \
		lightningd lightning_channeld lightning_closingd lightning_connectd \
		lightning_dualopend lightning_gossipd lightning_hsmd lightning_onchaind \
		lightning_openingd lightning_websocketd \
		/lightning_out/lightningd/
	cd ../plugins
	cp -a \
		autoclean bcli funder topology keysend offers pay txprepare spenderp \
		chanbackup commando exposesecret recklessrpc recover cln-renepay cln-xpay \
		cln-askrene sql bookkeeper \
		/lightning_out/plugins/
	cp -a clnrest/clnrest /lightning_out/plugins/clnrest/clnrest	
	cp -a wss-proxy/wss-proxy /lightning_out/plugins/wss-proxy/wss-proxy

	rm /lightnind
	mv /lightning_out /lightning
}
build() {
	cln_build
	cln_finalize
}
####################
build
