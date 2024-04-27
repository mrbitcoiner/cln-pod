#!/usr/bin/env bash
####################
set -e
####################
readonly RELDIR="$(dirname ${0})"
readonly IMAGE_NAME="cln"
####################
eprintln() {
	! [ -z "${1}" ] || eprintln 'eprintln: undefined message'
	printf "${1}\n" 1>&2
	return 1
}
env_check() {
	[ -e "${RELDIR}/.env" ] || eprintln '.env does not exist'
	source "${RELDIR}/.env"
	! [ -z "${CONTAINER_NAME}" ] || eprintln 'undefined env: CONTAINER_NAME'
	! [ -z "${TOR_PROXY}" ] || eprintln 'undefined env: TOR_PROXY'
	! [ -z "${BITCOIN_NETWORK}" ] || eprintln 'undefined env: BITCOIN_NETWORK'
	! [ -z "${CLN_ALIAS}" ] || eprintln 'undefined env: CLN_ALIAS'
	! [ -z "${CLN_BASE_FEE_MSAT}" ] || eprintln 'undefined env: CLN_BASE_FEE_MSAT'
	! [ -z "${CLN_PPM_FEE}" ] || eprintln 'undefined env: CLN_PPM_FEE'
	! [ -z "${CLN_MIN_CH_CAPACITY_SAT}" ] || eprintln 'undefined env: CLN_MIN_CH_CAPACITY_SAT'
	! [ -z "${CLN_MAX_HTLC_INFLIGHT}" ] || eprintln 'undefined env: CLN_MAX_HTLC_INFLIGHT'
	! [ -z "${CLN_MIN_HTLC_SIZE_MSAT}" ] || eprintln 'undefined env: CLN_MIN_HTLC_SIZE_MSAT'
	! [ -z "${CLN_MAX_HTLC_SIZE_MSAT}" ] || eprintln 'undefined env: CLN_MAX_HTLC_SIZE_MSAT'
	! [ -z "${BITCOIN_CLI_PATH}" ] || eprintln 'undefined env: BITCOIN_CLI_PATH'
	! [ -z "${BITCOIN_RPC_USERNAME}" ] || eprintln 'undefined env: BITCOIN_RPC_USERNAME'
	! [ -z "${BITCOIN_RPC_PASSWORD}" ] || eprintln 'undefined env: BITCOIN_RPC_PASSWORD'
	! [ -z "${BITCOIN_RPC_PORT}" ] || eprintln 'undefined env: BITCOIN_RPC_PORT'
	! [ -z "${BITCOIN_RPC_HOSTNAME}" ] || eprintln 'undefined env: BITCOIN_RPC_HOSTNAME'
}
common() {
	env_check
	[ -e "${RELDIR}/volume/data" ] || mkdir -p "${RELDIR}/volume/data"
	[ -e "${BITCOIN_CLI_PATH}" ] || eprintln "not found ${BITCOIN_CLI_PATH}"
	[ -e "${RELDIR}/volume/data/bitcoin-cli" ] \
		|| cp -a "${BITCOIN_CLI_PATH}" "${RELDIR}/volume/data/bitcoin-cli"
	chmod +x "${RELDIR}"/volume/scripts/*.sh
}
build() {
	podman build \
		-f="${RELDIR}/Containerfile" \
		--tag="${IMAGE_NAME}" \
		"${RELDIR}"
}
up() {
	podman run \
		--rm \
		--env-file="${RELDIR}/.env" \
		-v="${RELDIR}/volume:/volume" \
		--name="${CONTAINER_NAME}" \
		"localhost/${IMAGE_NAME}" &
}
lightning-cli() {
	! [ -z "${1}" ] || eprintln 'Expected: <command>'
  podman exec ${CONTAINER_NAME} bash -c "lightning-cli ${1}"
}
invoice() {
	! [ -z "${1}" ] && ! [ -z "${2}" ] || ( \
		printf 'Expected: <description> <satoshi>\n' 1>&2 \
		&& return 1 \
	)
	local description="${1}"
	local satoshi="${2}"
	local label="$(dd if=/dev/urandom bs=1 count=64 2>/dev/null | sha256sum | awk '{print $1}')"
	local cmd="invoice -k msatoshi=\"${satoshi}sat\" label=\"${label}\" description=\"${description}\""
	lightning-cli "invoice -k msatoshi=\"${satoshi}sat\" label=\"${label}\" description=\"${description}\""
}
clean() {
	printf 'are you sure? This will delete all container data (Y/n): '
	read v
	[ "${v}" == "Y" ] || eprintln 'abort!'
	rm -rf "${RELDIR}/volume/data"
}
shutdown() {
	podman exec "${CONTAINER_NAME}" "/volume/scripts/stop.sh" || true
	podman stop "${CONTAINER_NAME}" || true
}
address() {
	lightning-cli 'getinfo' | jq '.address'
}
mk_systemd() {
	! [ -e "/etc/systemd/system/${CONTAINER_NAME}.service" ] \
		|| eprintln "service ${CONTAINER_NAME} already exists
"
	local user="${USER}"
	sudo bash -c "cat << EOF > /etc/systemd/system/${CONTAINER_NAME}.service
[Unit]
Description=CLN Pod
After=network.target

[Service]
Environment=\"PATH=/usr/local/bin:/usr/bin:/bin:${PATH}\"
User=${user}
Type=forking
ExecStart=/bin/bash -c \"cd ${PWD}/${RELDIR}; ./control.sh up\"
ExecStop=/bin/bash -c \"cd ${PWD}/${RELDIR}; ./control.sh down\"
Restart=on-failure
RestartSec=10s

[Install]
WantedBy=multi-user.target
EOF
"
	sudo systemctl enable "${CONTAINER_NAME}".service
}
rm_systemd() {
	[ -e "/etc/systemd/system/${CONTAINER_NAME}.service" ] || return 0
	sudo systemctl stop "${CONTAINER_NAME}".service || true
	sudo systemctl disable "${CONTAINER_NAME}".service
	sudo rm /etc/systemd/system/"${CONTAINER_NAME}".service
}

####################
common
case ${1} in
  build) build ;;
  up) up ;;
  down) shutdown ;;
  clean) clean ;;
  lightning-cli) lightning-cli "${2}" "${3}" ;;
	address) address ;;
	invoice) invoice "${2}" "${3}" ;;
	mk-systemd) mk_systemd ;;
	rm-systemd) rm_systemd ;;
  test) ;;
  *) eprintln 'Usage: < build | up | down | address | lightning-cli | invoice | mk-systemd | rm-systemd | clean >' ;;
esac
