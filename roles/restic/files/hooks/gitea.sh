#!/bin/bash

set -e

PATH="$PATH:/usr/local/bin:/usr/sbin:/sbin"

GITEA_USER=${GITEA_USER:-git}
GITEA_CONFIG=${GITEA_CONFIG:-/etc/gitea/app.ini}
GITEA_WORK_PATH=${GITEA_WORK_PATH:-/var/lib/gitea}
GITEA_CUSTOM_PATH=${GITEA_CUSTOM_PATH:-$GITEA_WORK_PATH/custom}
GITEA_BACKUP_PATH=${GITEA_BACKUP_PATH:-$GITEA_WORK_PATH/backup}
GITEA_KEEP_DAYS=${GITEA_KEEP_DAYS:-7}

prereq() {
    if ! systemctl list-units --full --all | grep -Fq "gitea.service"; then
        printf "gitea.service unit does not exit\n"
        exit 1
    fi

    if (( EUID != 0 )); then
        printf "must be run as root\n"
        exit 1
    fi
}

main() {
    prereq

    if [ "$1" == "pre" ]; then
        pushd "$GITEA_BACKUP_PATH" > /dev/null || printf "could not chdir to %s\n" "$GITEA_BACKUP_PATH"
        printf "gitea dump started\n"
        runuser -u "$GITEA_USER" -- \
            gitea dump \
            --config "$GITEA_CONFIG" \
            --work-path "$GITEA_WORK_PATH" \
            --custom-path "$GITEA_CUSTOM_PATH" > /dev/null
        printf "gitea dump complete\n"
        popd > /dev/null || printf "could not chdir to %s\n" "$OLDPWD"
    elif [ "$1" == "post" ]; then
        printf "purging gitea backups\n"
        find "$GITEA_BACKUP_PATH" \
            -type f \
            -name '*.zip' \
            -mtime "+$GITEA_KEEP_DAYS" \
            -delete
    fi
}

main "$@"
