#!/usr/bin/env bash
####################
set -e
####################
readonly LN_PORT=9735
readonly LN_DATADIR="/volume/data/.lightning"
readonly BITCOIN_CFGDIR="${HOME}/.bitcoin"
####################
eprintln() {
	! [ -z "${1}" ] || eprintln 'eprintln: undefined message'
	printf "${1}\n" 1>&2
	return 1
}
tor_setup() {
	[ "${TOR_PROXY}" == "enabled" ] || return 0
	[ -e "/volume/data/tor" ] || mkdir -p /volume/data/tor
	cat << EOF >> /etc/tor/torrc
HiddenServiceDir /volume/data/tor/cln
HiddenServicePort ${LN_PORT} 127.0.0.1:${LN_PORT}
EOF
	tor 1>/dev/null &
	while ! [ -e "/volume/data/tor/cln/hostname" ]; do
		echo "sleeping while tor hostname is not generated"
		sleep 1
	done
}
bitcoind_setup() {
	[ -e "${BITCOIN_CFGDIR}" ] || mkdir -p "${BITCOIN_CFGDIR}"
	cat << EOF > "${BITCOIN_CFGDIR}/bitcoin.conf"
rpcuser=${BITCOIN_RPC_USERNAME}
rpcpassword=${BITCOIN_RPC_PASSWORD}
rpcconnect=${BITCOIN_RPC_HOSTNAME}
rpcport=${BITCOIN_RPC_PORT}
EOF
}
cln_setup(){
	[ -e "${LN_DATADIR}" ] || mkdir -p "${LN_DATADIR}"
	ln -sf "${LN_DATADIR}" "${HOME}/.lightning"
	local ln_network=
	case ${BITCOIN_NETWORK} in
	mainnet) ln_network="bitcoin" ;;
	testnet) ln_network="testnet" ;;
	regtest) ln_network="regtest" ;;
	*) eprintln 'init.sh: invalid BITCOIN_NETWORK' ;;
	esac
	if [ "${TOR_PROXY}" == "enabled" ] \
		&& ! [ -e "/volume/data/tor/cln/hostname" ]; then
		eprintln 'TOR_PROXY is enabled but hostname does not exist'
	fi
	local announce_addr=
	if [ "${TOR_PROXY}" == "enabled" ]; then
		announce_addr="announce-addr=$(cat /volume/data/tor/cln/hostname):${LN_PORT}"
	fi
	local proxy=
	if [ "${TOR_PROXY}" == "enabled" ]; then
		proxy="proxy=127.0.0.1:9050"
	fi
	local always_use_proxy=
	if [ "${TOR_PROXY}" == "enabled" ]; then
		always_use_proxy="always-use-proxy=true"
	fi
	local htlc_maximum_msat=
	if [ ${CLN_MAX_HTLC_SIZE_MSAT} -gt 0 ]; then
		htlc_maximum_msat="htlc-maximum-msat=${CLN_MAX_HTLC_SIZE_MSAT}"
	fi
	local bitcoin_retry_timeout=""
	local bitcoin_rpcclienttimeout=""
	if ! [ -z "${BITCOIN_TIMEOUT}" ]; then
		bitcoin_retry_timeout="bitcoin-retry-timeout=${BITCOIN_TIMEOUT}" 
		bitcoin_rpcclienttimeout="bitcoin-rpcclienttimeout=${BITCOIN_TIMEOUT}" 
	fi
	cat << EOF > "${LN_DATADIR}/config"
####################
## NETWORK & INFO
network=${ln_network}
alias=${CLN_ALIAS}
rgb=000000
bind-addr=127.0.0.1:${LN_PORT}
#announce-addr=hostname:port
${announce_addr}
log-level=info
#proxy=127.0.0.1:9050
${proxy}
#always-use-proxy=true
${always_use_proxy}

####################
## BITCOIN 
${bitcoin_retry_timeout}
${bitcoin_rpcclienttimeout}

####################
## PAYMENTS/ROUTING 
wumbo
min-capacity-sat=${CLN_MIN_CH_CAPACITY_SAT}
fee-base=${CLN_BASE_FEE_MSAT}
fee-per-satoshi=${CLN_PPM_FEE}
htlc-minimum-msat=${CLN_MIN_HTLC_SIZE_MSAT}
#htlc-maximum-msat=0
${htlc_maximum_msat}
max-concurrent-htlcs=${CLN_MAX_HTLC_INFLIGHT}

####################
## OTHER
EOF
}
cln_start() {
	lightningd | tee -a /volume/data/lightning.log &
	local lightningd_pid="${!}"
	printf "${lightningd_pid}" > /volume/data/lightning.pid
	while kill -0 ${lightningd_pid} 1>/dev/null 2>&1; do
		sleep 1
	done
}
init() {
	tor_setup
	bitcoind_setup
	cln_setup
	cln_start # will block
}
####################
init
