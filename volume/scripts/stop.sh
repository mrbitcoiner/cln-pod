#!/usr/bin/env bash
####################
set -e
####################
####################
shutdown() {
	lightning-cli stop
	local pid=$(cat /volume/data/lightning.pid)
	while kill -0 ${pid} 1>/dev/null 2>&1; do
		echo 'waiting cln to stop'
		sleep 1
	done
}
####################
shutdown
