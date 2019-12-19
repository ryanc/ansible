#!/bin/bash

# {{ ansible_managed }}

error_exit() {
    printf "%s\n" "$1"
    exit 1
}

RESTIC_ETC_PATH=${RESTIC_ETC_PATH:-/etc/restic}
RESTIC_PATH=${RESTIC_PATH:-/usr/local/bin/restic}

MAX_ATTEMPTS=60
MAX_SLEEP=43200  # 12 hours
REPO=$1

if [ -z "$REPO" ]; then
    error_exit "repo is missing"
fi

REPO_PATH="${RESTIC_ETC_PATH}/repos/${REPO}"
REPO_ENV="${REPO_PATH}/env.sh"

if [ ! -r "$REPO_ENV" ]; then
    error_exit "${REPO_ENV} does not exist"
fi

# shellcheck disable=SC1090
. "$REPO_ENV"

KEEP_HOURLY=${KEEP_HOURLY:-24}
KEEP_DAILY=${KEEP_DAILY:-7}
KEEP_WEEKLY=${KEEP_WEEKLY:-5}
KEEP_MONTHLY=${KEEP_MONTHLY:-12}
KEEP_YEARLY=${KEEP_YEARLY:-10}

# initial sleep
sleep "$(((RANDOM % MAX_SLEEP) + 1))s"

counter=0
sleep=1
rc=1

until [ $counter -eq "$MAX_ATTEMPTS" ] || [ $rc -eq 0 ]; do
    $RESTIC_PATH forget \
        --quiet \
        --host "$(hostname -f)" \
        --keep-hourly "$KEEP_HOURLY" \
        --keep-daily "$KEEP_DAILY" \
        --keep-weekly "$KEEP_WEEKLY" \
        --keep-monthly "$KEEP_MONTHLY" \
        --keep-yearly "$KEEP_YEARLY" \
        --prune

    rc=$?

    if [ $rc -ne 0 ]; then
      sleep=$((counter * 5))
      printf "sleeping for %d seconds (%d)\n" $sleep $counter
      sleep $sleep
    fi

    (( counter++ ))
done

if [ $rc -ne 0 ] && [ $counter -eq "$MAX_ATTEMPTS" ]; then
    printf "tidy timed out, exiting\n"
fi