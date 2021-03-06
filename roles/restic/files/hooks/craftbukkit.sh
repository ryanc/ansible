#!/bin/bash

set -e

SERVICE=craftbukkit.service
VAR_DIR=/var/opt/craftbukkit
WAIT=30
VERBOSE=${VERBOSE:-4}

prereq() {
    local service=$1
    if ! systemctl list-units --full --all | grep -Fq "$service"; then
        printf "%s unit does not exit\n" "$service"
        exit 1
    fi
}

error_exit() {
    printf "%s\n" "$1" >&2
    exit 1
}

stop_server() {
    local unit="${1:-$SERVICE}"
    local attempts="${2:-$WAIT}"

    if ! systemctl -q is-enabled "$unit"; then
        printf "%s is not enabled, skipping.\n" "$unit"
        return 0
    fi

    if ! systemctl -q is-active "$unit"; then
        printf "%s is already stopped\n" "$unit"
        return 0
    fi

    systemctl -q stop "$unit"

    while systemctl -q is-active "$unit"; do
        printf "waiting for %s to stop ... (%s)\n" "$unit" "$attempts"
        ((attempts--))
        if ((attempts == 0)); then
            return 1
        fi
        sleep 1
    done

    return 0
}

start_server() {
    local unit="${1:-$SERVICE}"
    local attempts="${2:-$WAIT}"

    if ! systemctl -q is-enabled "$unit"; then
        printf "%s is not enabled, skipping.\n" "$unit"
        return 0
    fi

    if systemctl -q is-active "$unit"; then
        printf "%s is already started\n" "$unit"
        return 0
    fi

    systemctl -q start "$unit"

    while ! systemctl -q is-active "$unit"; do
        printf "waiting for %s to start ... (%d)\n" "$unit" "$attempts"
        ((attempts--))
        if ((attempts == 0)); then
            return 1
        fi
        sleep 1
    done

    return 0
}


open_files() {
    local dir=${1-$VAR_DIR}
    local attempts="${2:-$WAIT}"

    while (($(lsof +D "$dir" | wc -l) > 0)); do
        printf "waiting for open files ... (%d)\n" "$attempts"
        ((attempts--))
        if ((attempts == 0)); then
            return 1
        fi
        sleep 1
    done

    return 0
}


main() {

    if [ "$1" == "pre" ]; then
        if ! stop_server $SERVICE; then
            error_exit "Failed to stop $SERVICE"
        fi

        printf "checking for open files\n"

        if ! open_files $VAR_DIR; then
            error_exit "Open files exist in $VAR_DIR"
        fi
    elif [ "$1" == "post" ]; then
        if ! start_server $SERVICE; then
            error_exit "Failed to start $SERVICE"
        fi
    fi
}

main "$@"
