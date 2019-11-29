#!/bin/bash

SERVICE=minecraft.service
BACKUP_DIR=/opt/minecraft/backup
VAR_DIR=/opt/minecraft/var
SCRATCH=$(mktemp -p /var/tmp -d minecraft.XXXXXXXXXX)
NICE=15
TAR=minecraft-$(date +%Y-%m-%d).tar
WAIT=30
VERBOSE=${VERBOSE:-4}

declare -A LOG_LEVELS
LOG_LEVELS=(
    [emerg]=0
    [alert]=1
    [crit]=2
    [err]=3
    [warning]=4
    [notice]=5
    [info]=6
    [debug]=7
)

log() {
    local LEVEL
    local TS

    LEVEL=$1
    TS="$(date -Is)"
    shift

    if [[ $VERBOSE -ge ${LOG_LEVELS[$LEVEL]} ]]; then
        if [[ $# -ge 2 ]]; then
            local FMT=$1
            shift
            printf "%s [%s] ${FMT}\n" "${TS}" "$LEVEL" "$@"
        else
            echo "${TS} [$LEVEL]" "$@"
        fi
    fi
}

finish() {
    log info "Cleaning up"
    rm -rf "$SCRATCH"
    if ! systemctl -q is-active "$SERVICE"; then
        start_server $SERVICE
    fi
}
trap finish EXIT

error_exit() {
    log crit "$1"
    exit 1
}

stop_server() {
    local unit="${1:-$SERVICE}"
    local attempts="${2:-$WAIT}"

    if ! systemctl -q is-active "$unit"; then
        log warning "%s is already stopped\n" "$unit"
        return 0
    fi

    systemctl -q stop "$unit"

    while systemctl -q is-active "$unit"; do
        log warning "Waiting for %s to stop ... (%s)\n" "$unit" "$attempts"
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

    if systemctl -q is-active "$unit"; then
        log warning "%s is already started\n" "$unit"
        return 0
    fi

    systemctl -q start "$unit"

    while ! systemctl -q is-active "$unit"; do
        log warning "Waiting for %s to start ... (%d)\n" "$unit" "$attempts"
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
        log warning "Waiting for open files ... (%d)\n" "$attempts"
        ((attempts--))
        if ((attempts == 0)); then
            return 1
        fi
        sleep 1
    done

    return 0
}


main() {
    log info "Stopping %s service" $SERVICE
    if ! stop_server $SERVICE; then
        error_exit "Failed to stop $SERVICE"
    fi

    log info "Checking for open files"
    if ! open_files $VAR_DIR; then
        error_exit "Open files exist in $VAR_DIR"
    fi

    log info "Starting backup"
    if ! tar -cf "$SCRATCH/$TAR" -C "$VAR_DIR" world; then
        error_exit "Archive failed"
    fi

    log info "Starting %s service" $SERVICE
    if ! start_server $SERVICE; then
        error_exit "Failed to start $SERVICE"
    fi

    log info "Compressing $TAR"
    if ! nice -n "$NICE" xz -9 "$SCRATCH/$TAR"; then
        error_exit "Failed to compress $SCRATCH/$TAR"
    else
        mv "$SCRATCH/$TAR.xz" "$BACKUP_DIR"
        log info "Symlinking current archive"
        ln -nfs "$BACKUP_DIR/$TAR.xz" "$BACKUP_DIR/minecraft-latest.tar.xz"
    fi
}

main
