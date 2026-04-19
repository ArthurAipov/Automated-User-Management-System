#!/usr/bin/env bash
# cleanup_expired.sh – Remove expired user accounts listed in a CSV file.
#
# This script is designed to be called by the systemd timer (user-cleanup.timer)
# or run manually:
#
#   sudo ./cleanup_expired.sh [--csv FILE]
#
# It delegates to manage_users.sh with the 'cleanup' command so that all
# logging, SSH-key handling, and process-kill logic is centralised.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANAGE_SCRIPT="${SCRIPT_DIR}/manage_users.sh"
DEFAULT_CSV="${SCRIPT_DIR}/users.csv"

if [[ ! -x "${MANAGE_SCRIPT}" ]]; then
    echo "ERROR: manage_users.sh not found or not executable at ${MANAGE_SCRIPT}" >&2
    exit 1
fi

csv_file="${DEFAULT_CSV}"
while [[ $# -gt 0 ]]; do
    case "$1" in
        --csv)
            csv_file="$2"
            shift 2
            ;;
        -h|--help)
            echo "Usage: sudo $0 [--csv FILE]"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

exec "${MANAGE_SCRIPT}" cleanup --csv "${csv_file}"
