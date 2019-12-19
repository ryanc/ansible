#!/bin/bash

# Ansible managed

error_exit() {
    printf "%s\n" "$1"
    exit 1
}

RESTIC_ETC_PATH=${RESTIC_ETC_PATH:-/etc/restic}
RESTIC_PATH=${RESTIC_PATH:-/usr/local/bin/restic}

if [ $# -lt 2 ]; then
    error_exit "missing arguments"
fi

REPO=$1
shift

REPO_PATH="${RESTIC_ETC_PATH}/repos/${REPO}"
REPO_ENV="${REPO_PATH}/env.sh"

if [ ! -r "$REPO_ENV" ]; then
    error_exit "${REPO_ENV} does not exist"
fi

# shellcheck disable=SC1090
. "$REPO_ENV"

$RESTIC_PATH "$@"
