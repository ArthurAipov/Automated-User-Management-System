#!/usr/bin/env bash
# manage_users.sh – Automated User Management System
# Manages user accounts from a CSV file.
#
# Usage:
#   sudo ./manage_users.sh create   [--csv FILE]
#   sudo ./manage_users.sh delete   [--csv FILE]
#   sudo ./manage_users.sh list
#   sudo ./manage_users.sh cleanup  [--csv FILE]
#
# CSV format (no spaces around commas):
#   username,group,home_directory,expiry_date
# where expiry_date is YYYY-MM-DD.

set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_CSV="${SCRIPT_DIR}/users.csv"
LOG_FILE="${SCRIPT_DIR}/user_management.log"

# Password policy (days)
PASS_MAX_DAYS=90
PASS_MIN_DAYS=7
PASS_WARN_DAYS=14

# SSH key algorithm
SSH_KEY_TYPE="ed25519"

# ── Logging ──────────────────────────────────────────────────────────────────

log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp
    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "${timestamp} [${level}] ${message}" | tee -a "${LOG_FILE}"
}

info()    { log "INFO " "$@"; }
success() { log "OK   " "$@"; }
warn()    { log "WARN " "$@"; }
error()   { log "ERROR" "$@"; }

# ── Helpers ───────────────────────────────────────────────────────────────────

require_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (sudo)."
        exit 1
    fi
}

ensure_group() {
    local group="$1"
    if ! getent group "${group}" &>/dev/null; then
        groupadd "${group}"
        info "Created group '${group}'."
    fi
}

# Convert YYYY-MM-DD to seconds since epoch (portable: date -d on Linux).
date_to_epoch() {
    date -d "$1" '+%s' 2>/dev/null || { error "Invalid date: $1"; return 1; }
}

is_expired() {
    local expiry_date="$1"
    local expiry_epoch now_epoch
    expiry_epoch="$(date_to_epoch "${expiry_date}")"
    now_epoch="$(date '+%s')"
    [[ "${now_epoch}" -gt "${expiry_epoch}" ]]
}

# ── SSH key generation ────────────────────────────────────────────────────────

generate_ssh_key() {
    local username="$1"
    local group="$2"
    local home_dir="$3"
    local ssh_dir="${home_dir}/.ssh"
    local key_file="${ssh_dir}/id_${SSH_KEY_TYPE}"

    if [[ -f "${key_file}" ]]; then
        warn "SSH key already exists for '${username}'. Skipping."
        return 0
    fi

    mkdir -p "${ssh_dir}"
    chmod 700 "${ssh_dir}"

    ssh-keygen -t "${SSH_KEY_TYPE}" -f "${key_file}" -N "" -C "${username}@$(hostname)" -q

    # Add public key to authorized_keys so the user can log in with it.
    cat "${key_file}.pub" >> "${ssh_dir}/authorized_keys"
    chmod 600 "${ssh_dir}/authorized_keys"
    chmod 600 "${key_file}"
    chmod 644 "${key_file}.pub"

    chown -R "${username}:${group}" "${ssh_dir}"

    success "Generated ${SSH_KEY_TYPE} SSH key for '${username}': ${key_file}"
}

# ── Password policy ───────────────────────────────────────────────────────────

set_password_policy() {
    local username="$1"
    local expiry_date="$2"

    # chage sets account aging information.
    chage \
        --maxdays  "${PASS_MAX_DAYS}" \
        --mindays  "${PASS_MIN_DAYS}" \
        --warndays "${PASS_WARN_DAYS}" \
        --expiredate "${expiry_date}" \
        "${username}"

    success "Password policy set for '${username}' (expires ${expiry_date})."
}

# ── User creation ─────────────────────────────────────────────────────────────

create_user() {
    local username="$1"
    local group="$2"
    local home_dir="$3"
    local expiry_date="$4"

    # Validate expiry date format.
    if ! date -d "${expiry_date}" &>/dev/null; then
        error "Invalid expiry date '${expiry_date}' for user '${username}'. Skipping."
        return 1
    fi

    # Ensure the primary group exists.
    ensure_group "${group}"

    if id "${username}" &>/dev/null; then
        warn "User '${username}' already exists. Skipping creation."
    else
        useradd \
            --gid     "${group}" \
            --home    "${home_dir}" \
            --create-home \
            --shell   /bin/bash \
            "${username}"

        # Set secure home directory permissions (700).
        chmod 700 "${home_dir}"
        chown "${username}:${group}" "${home_dir}"

        # Lock the password until an admin sets one (forces SSH-key login).
        passwd -l "${username}" &>/dev/null

        success "Created user '${username}' (group=${group}, home=${home_dir})."
    fi

    # Always apply / refresh the password policy and SSH key.
    set_password_policy "${username}" "${expiry_date}"
    generate_ssh_key    "${username}" "${group}" "${home_dir}"
}

# ── User deletion ─────────────────────────────────────────────────────────────

delete_user() {
    local username="$1"
    local home_dir="$2"

    if ! id "${username}" &>/dev/null; then
        warn "User '${username}' does not exist. Skipping deletion."
        return 0
    fi

    # Kill any active processes owned by this user.
    pkill -u "${username}" 2>/dev/null || true

    if ! userdel --remove "${username}" 2>/dev/null; then
        warn "userdel --remove failed for '${username}'; retrying without --remove flag."
        userdel "${username}"
    fi

    # Remove home directory if userdel left it behind.
    if [[ -d "${home_dir}" ]]; then
        rm -rf "${home_dir}"
        info "Removed home directory '${home_dir}'."
    fi

    success "Deleted user '${username}'."
}

# ── CSV processing ────────────────────────────────────────────────────────────

process_csv() {
    local csv_file="$1"
    local action="$2"   # create | delete | cleanup

    if [[ ! -f "${csv_file}" ]]; then
        error "CSV file not found: ${csv_file}"
        exit 1
    fi

    local line_num=0
    while IFS=',' read -r username group home_dir expiry_date; do
        (( line_num++ )) || true

        # Skip header and blank/comment lines.
        [[ "${line_num}" -eq 1 && "${username}" == "username" ]] && continue
        [[ -z "${username}" || "${username}" == \#* ]]           && continue

        # Trim any trailing carriage returns (Windows line endings).
        username="${username//$'\r'/}"
        group="${group//$'\r'/}"
        home_dir="${home_dir//$'\r'/}"
        expiry_date="${expiry_date//$'\r'/}"

        case "${action}" in
            create)
                info "Processing create for '${username}'…"
                create_user "${username}" "${group}" "${home_dir}" "${expiry_date}"
                ;;
            delete)
                info "Processing delete for '${username}'…"
                delete_user "${username}" "${home_dir}"
                ;;
            cleanup)
                if is_expired "${expiry_date}"; then
                    info "Account '${username}' expired on ${expiry_date}. Removing…"
                    delete_user "${username}" "${home_dir}"
                else
                    info "Account '${username}' is active (expires ${expiry_date}). Skipping."
                fi
                ;;
            *)
                error "Unknown action '${action}'."
                exit 1
                ;;
        esac
    done < "${csv_file}"
}

# ── List managed users ────────────────────────────────────────────────────────

list_users() {
    local csv_file="$1"

    if [[ ! -f "${csv_file}" ]]; then
        error "CSV file not found: ${csv_file}"
        exit 1
    fi

    printf "%-15s %-12s %-25s %-12s %-8s\n" \
        "USERNAME" "GROUP" "HOME" "EXPIRES" "EXISTS"
    printf '%s\n' "$(printf '─%.0s' {1..75})"

    local line_num=0
    while IFS=',' read -r username group home_dir expiry_date; do
        (( line_num++ )) || true
        [[ "${line_num}" -eq 1 && "${username}" == "username" ]] && continue
        [[ -z "${username}" || "${username}" == \#* ]]           && continue

        username="${username//$'\r'/}"
        group="${group//$'\r'/}"
        home_dir="${home_dir//$'\r'/}"
        expiry_date="${expiry_date//$'\r'/}"

        local exists="no"
        id "${username}" &>/dev/null && exists="yes"

        local expired_mark=""
        is_expired "${expiry_date}" && expired_mark=" [EXPIRED]"

        printf "%-15s %-12s %-25s %-12s %-8s%s\n" \
            "${username}" "${group}" "${home_dir}" \
            "${expiry_date}" "${exists}" "${expired_mark}"
    done < "${csv_file}"
}

# ── Entry point ───────────────────────────────────────────────────────────────

usage() {
    cat <<EOF
Usage: sudo $0 <command> [options]

Commands:
  create   Create users defined in the CSV file.
  delete   Delete users defined in the CSV file.
  list     List users defined in the CSV file with status.
  cleanup  Remove only expired user accounts.

Options:
  --csv FILE   Path to CSV file (default: ${DEFAULT_CSV})

CSV format (first line is header):
  username,group,home_directory,expiry_date

Example:
  sudo $0 create --csv /path/to/users.csv
EOF
}

main() {
    if [[ $# -eq 0 ]]; then
        usage
        exit 1
    fi

    local command="$1"
    shift

    # Parse optional --csv flag.
    local csv_file="${DEFAULT_CSV}"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --csv)
                csv_file="$2"
                shift 2
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    case "${command}" in
        -h|--help)
            usage
            exit 0
            ;;
    esac

    info "=== manage_users.sh started (command=${command}, csv=${csv_file}) ==="

    case "${command}" in
        create|delete|cleanup)
            require_root
            process_csv "${csv_file}" "${command}"
            ;;
        list)
            list_users "${csv_file}"
            ;;
        *)
            error "Unknown command: '${command}'"
            usage
            exit 1
            ;;
    esac

    info "=== manage_users.sh finished ==="
}

main "$@"
