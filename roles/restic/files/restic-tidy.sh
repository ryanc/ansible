#!/bin/bash

# {{ ansible_managed }}

error_exit() {
    printf "%s\n" "$1"
    exit 1
}

RESTIC_ETC_PATH=${RESTIC_ETC_PATH:-/etc/restic}
LOCK_PATH=/run/restic
LOCK="${LOCK_PATH}/tidy.lock"
KEEP_LOCK=

function finish {
    if [ -z "$KEEP_LOCK" ]; then
        rm -f "$LOCK"
    fi
}
trap finish EXIT

# shellcheck source=/dev/null
source "${RESTIC_ETC_PATH}/env.sh"

if [ "$RESTIC_SELF_UPDATE" -eq 1 ]; then
  printf "running restic self-update\n"
  $RESTIC_PATH self-update
fi

# initial sleep
MAX_ATTEMPTS=60
MAX_SLEEP=43200  # 12 hours
SLEEP="$(((RANDOM % MAX_SLEEP) + 1))s"
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

if [ -f "$LOCK" ]; then
    pid=$(cat "$LOCK")
    if ! kill -0 "$pid" 2> /dev/null; then
        printf "removing orphaned lock, pid %d does not exist\n" "$pid"
        rm -f "$LOCK"
    else
        if [[ -f "/proc/${pid}/cmdline" ]]; then
            cmdline=$(tr "\0" " " <"/proc/${pid}/cmdline")
            if ! [[ $cmdline =~ $(basename "$0") ]]; then
                printf "removing orphaned lock, pid %d belongs to another process\n" "$pid"
                rm -f "$LOCK"
            else
                KEEP_LOCK=1
                error_exit "another job is running, pid=${pid}"
            fi
        fi
    fi
fi

printf "started, keep hourly:%d daily:%d weekly:%d monthly:%d year:%d\n" \
    "$KEEP_HOURLY" \
    "$KEEP_DAILY" \
    "$KEEP_WEEKLY" \
    "$KEEP_MONTHLY" \
    "$KEEP_YEARLY"

printf "sleeping for %s (initial)\n" $SLEEP

sleep $SLEEP

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

if [ $rc -ne 0 ] && [ "$counter" -eq "$MAX_ATTEMPTS" ]; then
    printf "tidy timed out, exiting\n"
else
    printf "complete\n"
fi
