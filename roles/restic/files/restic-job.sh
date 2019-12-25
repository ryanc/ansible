#!/bin/bash

# Ansible managed

error_exit() {
    printf "%s\n" "$1"
    exit 1
}

RESTIC_ETC_PATH=${RESTIC_ETC_PATH:-/etc/restic}
RESTIC_PATH=${RESTIC_PATH:-/usr/local/bin/restic}

MAX_ATTEMPTS=60
NICE="ionice -c2 nice -n19"
JOB=$1

if [ -z "$JOB" ]; then
    error_exit "job is missing"
fi

JOB_PATH="${RESTIC_ETC_PATH}/jobs/${JOB}"
JOB_ENV="${JOB_PATH}/env.sh"
HOOKS_PATH="${JOB_PATH}/hooks.d"

if [ ! -r "$JOB_ENV" ]; then
    error_exit "${JOB_ENV} does not exist"
fi

# shellcheck disable=SC1090
. "$JOB_ENV"

if [ -z "${REPO+x}" ]; then
    error_exit "\$REPO is not set"
fi

REPO_PATH="${RESTIC_ETC_PATH}/repos/${REPO}"
REPO_ENV="${REPO_PATH}/env.sh"

if [ ! -r "$REPO_ENV" ]; then
    error_exit "${REPO_ENV} does not exist"
fi

# shellcheck disable=SC1090
. "$REPO_ENV"

EXCLUDE_PATH="${JOB_PATH}/exclude.txt"

if [ -z "${PATHS+x}" ]; then
    error_exit "\$PATHS is not set"
fi

printf "job '%s' started\n" "$JOB"

if [ -d "${HOOKS_PATH}" ]; then
    printf "running '%s' job pre-hooks\n" "$JOB"
    if ! run-parts --exit-on-error -v -a pre "${HOOKS_PATH}"; then
        printf "'%s' pre-hooks failed, running post-hooks and exiting\n" "$JOB"
        run-parts --exit-on-error -v -a post "${HOOKS_PATH}"
        exit 1
    fi
fi

counter=0
sleep=1
rc=1

until [ $counter -eq "$MAX_ATTEMPTS" ] || [ $rc -eq 0 ]; do
    if [ -r "$EXCLUDE_PATH" ]; then
        $NICE "$RESTIC_PATH" backup -q --exclude-file="${EXCLUDE_PATH}" "${PATHS}"
    else
        $NICE "$RESTIC_PATH" backup -q "${PATHS}"
    fi

    rc=$?

    if [ $rc -ne 0 ]; then
      sleep=$((counter * 5))
      printf "sleeping for %d seconds (%d)\n" $sleep $counter
      sleep $sleep
    fi

    (( counter++ ))
done

if [ $rc -ne 0 ] && [ $counter -eq "$MAX_ATTEMPTS" ]; then
  printf "restic job timed out, exiting\n"
else
    printf "job '%s' complete\n" "$JOB"
fi

if [ -d "${HOOKS_PATH}" ]; then
    printf "running '%s' job post-hooks\n" "$JOB"
    run-parts --exit-on-error -v -a post "${HOOKS_PATH}"
fi
