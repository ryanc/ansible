#!/bin/bash

function usage { printf "Usage: %s FILE\n" "$(basename "$0")" >&2; exit 1; }

while getopts "h" opt; do
    case "${opt}" in
        *)
            usage
            ;;
    esac
done
shift $((OPTIND-1))

FILE="$1"

if [ -z "${FILE}" ]; then
    usage
    exit 1
fi

if command -v sponge > /dev/null; then
    ( echo "# promcat (sponge)" ; cat /dev/stdin ) | sponge "${FILE}"
else
    TEMP=$(mktemp --suffix .prom)

    function finish {
        if [ -f "${TEMP}" ]; then
            rm -f "${TEMP}"
        fi
    }
    trap finish EXIT

    echo "# promcat (mktemp, mv)" > "${TEMP}"
    cat /dev/stdin >> "${TEMP}"

    if [ ! -s "${TEMP}" ] || grep -q '^[[:space:]]*$' "${TEMP}" ; then
        printf "%s is empty\n" "${TEMP}" >&2
        exit 1
    else
        mv "${TEMP}" "${FILE}"
    fi
fi
