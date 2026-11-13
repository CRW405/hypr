#!/usr/bin/env bash
set -u

usage() {
    printf 'Usage: %s notify <title> <message> | run <title> -- <command> [args...]\n' "${0##*/}" >&2
    exit 2
}

notify_error() {
    local title="$1"
    local message="$2"

    if command -v notify-send >/dev/null 2>&1; then
        notify-send --app-name=HyprQS --urgency=critical "$title" "$message"
    else
        printf 'HyprQS error: %s: %s\n' "$title" "$message" >&2
    fi
}

case "${1:-}" in
    notify)
        (($# == 3)) || usage
        notify_error "$2" "$3"
        ;;
    run)
        (($# >= 4)) || usage
        title="$2"
        shift 2
        [[ "$1" == -- ]] || usage
        shift

        stderr_file="$(mktemp "${TMPDIR:-/tmp}/hyprqs-error.XXXXXX")" || exit 1
        trap 'rm -f -- "$stderr_file"' EXIT

        "$@" >/dev/null 2>"$stderr_file"
        status=$?
        if ((status != 0 && status != 129 && status != 130 && status != 143)); then
            details="$(head -c 1200 -- "$stderr_file")"
            if [[ -z "$details" ]]; then
                details="Command exited with status $status."
            fi
            notify_error "$title" "$details"
        fi
        exit "$status"
        ;;
    *)
        usage
        ;;
esac
