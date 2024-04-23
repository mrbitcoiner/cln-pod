#!/usr/bin/env bash
####################
set -e
####################
readonly CLN_REPO='https://github.com/elementsproject/lightning'
readonly COMMIT_VERSION='v0.11.2'
####################
cln_build() {
	git clone ${CLN_REPO} /lightning
	cd /lightning
	git checkout ${COMMIT_VERSION}
	poetry run pip3 install --upgrade pip
	poetry run pip3 install mako
	poetry run pip3 install mrkd
	poetry install || true
	poetry run ./configure
	poetry run make
}
build() {
	cln_build
}
####################
build
