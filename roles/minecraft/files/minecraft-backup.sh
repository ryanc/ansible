#!/bin/bash

SERVICE=minecraft.service
BACKUP_DIR=/opt/minecraft/backup
VAR_DIR=/opt/minecraft/var
SCRATCH=$(mktemp -p /var/tmp -d minecraft.XXXXXXXXXX)
NICE=15
TAR=minecraft-$(date +%Y-%m-%d).tar
WAIT=30

finish() {
    printf "Cleaning up ...\n"
    rm -rf "$SCRATCH"
    if ! systemctl -q is-active "$SERVICE"; then
        start_server
    fi
}
trap finish EXIT

error_exit() {
    printf "%s\n" "$1"
    exit 1
}

stop_server() {
    local unit="${1:-$SERVICE}"
    local attempts="${2:-$WAIT}"

    if ! systemctl -q is-active "$unit"; then
        printf "%s is already stopped\n" "$unit"
        return 0
    fi

    systemctl -q stop "$unit"

    while systemctl -q is-active "$unit"; do
        printf "Waiting for %s to stop ... (%s)\n" "$unit" "$attempts"
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
        printf "%s is already started\n" "$unit"
        return 0
    fi

    systemctl -q start "$unit"

    while ! systemctl -q is-active "$unit"; do
        printf "Waiting for %s to start ... (%d)\n" "$unit" "$attempts"
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
        printf "Waiting for open files ... (%d)\n" "$attempts"
        ((attempts--))
        if ((attempts == 0)); then
            return 1
        fi
        sleep 1
    done

    return 0
}


main() {
    if ! stop_server; then
        error_exit "Failed to stop $SERVICE"
    fi

    if ! open_files; then
        error_exit "Open files exist in $VAR_DIR"
    fi

    if ! tar -cf "$SCRATCH/$TAR" -C "$VAR_DIR" world; then
        error_exit "Archive failed"
    fi

    if ! start_server; then
        error_exit "Failed to start $SERVICE"
    fi

    if ! nice -n "$NICE" xz -9 "$SCRATCH/$TAR"; then
        error_exit "Failed to compress $SCRATCH/$TAR"
    else
        mv "$SCRATCH/$TAR.xz" "$BACKUP_DIR"
        ln -nfs "$BACKUP_DIR/$TAR.xz" "$BACKUP_DIR/minecraft-latest.tar.xz"
    fi
}

main
