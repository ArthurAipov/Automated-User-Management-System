#!/usr/bin/env bash
set -euo pipefail

MANAGED_GROUP="managed_users"
LOG_FILE="/var/log/user_manager.log"
DEFAULT_SHELL="/bin/bash"
DRY_RUN=0

usage() {
    cat <<'USAGE'
Automated User Management System

Usage:
  sudo ./scripts/user_manager.sh --create users.csv [--dry-run]
  sudo ./scripts/user_manager.sh --cleanup-expired [--dry-run]
  ./scripts/user_manager.sh --help

Commands:
  --create CSV_FILE       Create or update managed users from a CSV file.
  --cleanup-expired      Delete expired users who belong to managed_users.
  --dry-run              Show and log planned actions without changing users.
  --help                 Show this help message.

CSV format:
  username,group,home,expiry
  student01,students,/home/student01,2026-12-31
USAGE
}

log_action() {
    local action="$1"
    local username="$2"
    local result="$3"
    local timestamp

    timestamp="$(date '+%Y-%m-%d %H:%M:%S')"
    printf '%s | action=%s | username=%s | result=%s\n' \
        "$timestamp" "$action" "$username" "$result" >> "$LOG_FILE"
}

die() {
    local message="$1"
    printf 'ERROR: %s\n' "$message" >&2
    log_action "ERROR" "system" "$message"
    exit 1
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        printf 'ERROR: This script must be run as root. Try sudo.\n' >&2
        exit 1
    fi
}

ensure_log_file() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
}

trim() {
    local value="$1"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    printf '%s' "$value"
}

validate_username() {
    local username="$1"
    [[ "$username" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

validate_group_name() {
    local group="$1"
    [[ "$group" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

validate_home_directory() {
    local home_dir="$1"
    [[ "$home_dir" =~ ^/home/[a-z_][a-z0-9_-]{0,31}$ ]]
}

validate_expiry_date() {
    local expiry="$1"
    [[ "$expiry" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]] || return 1
    date -d "$expiry" '+%Y-%m-%d' >/dev/null 2>&1
}

run_command() {
    local action="$1"
    local username="$2"
    shift 2

    if [[ "$DRY_RUN" -eq 1 ]]; then
        printf '[DRY-RUN] %s: %s\n' "$action" "$*"
        log_action "DRY_RUN_${action}" "$username" "$*"
        return 0
    fi

    if "$@"; then
        log_action "$action" "$username" "success"
        return 0
    fi

    log_action "$action" "$username" "failed command: $*"
    return 1
}

ensure_group() {
    local group="$1"

    if getent group "$group" >/dev/null; then
        log_action "GROUP_EXISTS" "system" "$group"
        return 0
    fi

    run_command "CREATE_GROUP" "system" groupadd "$group"
}

is_managed_user() {
    local username="$1"
    id -nG "$username" 2>/dev/null | tr ' ' '\n' | grep -Fxq "$MANAGED_GROUP"
}

set_home_permissions() {
    local username="$1"
    local group="$2"
    local home_dir="$3"

    run_command "CREATE_HOME" "$username" install -d -m 700 -o "$username" -g "$group" "$home_dir" || return 1
    run_command "CHOWN_HOME" "$username" chown "$username:$group" "$home_dir" || return 1
    run_command "CHMOD_HOME" "$username" chmod 700 "$home_dir" || return 1
}

set_password_policy() {
    local username="$1"
    local expiry="$2"

    run_command "SET_PASSWORD_POLICY" "$username" chage -M 90 -W 7 -E "$expiry" "$username"
}

generate_ssh_keys() {
    local username="$1"
    local group="$2"
    local home_dir="$3"
    local ssh_dir="${home_dir}/.ssh"
    local private_key="${ssh_dir}/id_ed25519"
    local public_key="${private_key}.pub"

    run_command "CREATE_SSH_DIR" "$username" install -d -m 700 -o "$username" -g "$group" "$ssh_dir" || return 1

    if [[ -f "$private_key" && -f "$public_key" ]]; then
        log_action "SSH_KEY_EXISTS" "$username" "$private_key"
    else
        run_command "GENERATE_SSH_KEY" "$username" ssh-keygen -t ed25519 -f "$private_key" -N "" -C "${username}@$(hostname)-managed" -q || return 1
    fi

    run_command "CHOWN_SSH" "$username" chown -R "$username:$group" "$ssh_dir" || return 1
    run_command "CHMOD_SSH_DIR" "$username" chmod 700 "$ssh_dir" || return 1

    if [[ -f "$private_key" || "$DRY_RUN" -eq 1 ]]; then
        run_command "CHMOD_PRIVATE_KEY" "$username" chmod 600 "$private_key" || return 1
    fi

    if [[ -f "$public_key" || "$DRY_RUN" -eq 1 ]]; then
        run_command "CHMOD_PUBLIC_KEY" "$username" chmod 644 "$public_key" || return 1
    fi
}

create_or_update_user() {
    local username="$1"
    local group="$2"
    local home_dir="$3"
    local expiry="$4"

    ensure_group "$MANAGED_GROUP" || return 1
    ensure_group "$group" || return 1

    if id "$username" >/dev/null 2>&1; then
        if ! is_managed_user "$username"; then
            log_action "SKIP_UNMANAGED_EXISTING_USER" "$username" "user exists but is not in $MANAGED_GROUP"
            printf 'Skipping %s: existing user is not managed by this project.\n' "$username" >&2
            return 0
        fi

        run_command "UPDATE_USER" "$username" usermod -g "$group" -aG "$MANAGED_GROUP" -d "$home_dir" -s "$DEFAULT_SHELL" -e "$expiry" "$username" || return 1
    else
        run_command "CREATE_USER" "$username" useradd -m -d "$home_dir" -s "$DEFAULT_SHELL" -g "$group" -G "$MANAGED_GROUP" -e "$expiry" "$username" || return 1
    fi

    set_home_permissions "$username" "$group" "$home_dir" || return 1
    set_password_policy "$username" "$expiry" || return 1
    generate_ssh_keys "$username" "$group" "$home_dir" || return 1

    log_action "USER_READY" "$username" "home=$home_dir group=$group expiry=$expiry"
}

process_csv() {
    local csv_file="$1"
    local line_number=0
    local failure_count=0

    [[ -f "$csv_file" ]] || die "CSV file not found: $csv_file"

    while IFS=, read -r username group home_dir expiry extra_field || [[ -n "${username:-}" ]]; do
        line_number=$((line_number + 1))

        if [[ "$line_number" -eq 1 ]]; then
            continue
        fi

        username="$(trim "${username:-}")"
        group="$(trim "${group:-}")"
        home_dir="$(trim "${home_dir:-}")"
        expiry="$(trim "${expiry:-}")"

        if [[ -z "$username$group$home_dir$expiry" ]]; then
            continue
        fi

        if [[ -n "${extra_field:-}" ]]; then
            log_action "INVALID_CSV" "line_${line_number}" "too many columns"
            failure_count=$((failure_count + 1))
            continue
        fi

        if ! validate_username "$username"; then
            log_action "INVALID_USERNAME" "$username" "line $line_number"
            failure_count=$((failure_count + 1))
            continue
        fi

        if ! validate_group_name "$group"; then
            log_action "INVALID_GROUP" "$username" "line $line_number group=$group"
            failure_count=$((failure_count + 1))
            continue
        fi

        if ! validate_home_directory "$home_dir"; then
            log_action "INVALID_HOME" "$username" "line $line_number home=$home_dir"
            failure_count=$((failure_count + 1))
            continue
        fi

        if ! validate_expiry_date "$expiry"; then
            log_action "INVALID_EXPIRY" "$username" "line $line_number expiry=$expiry"
            failure_count=$((failure_count + 1))
            continue
        fi

        if ! create_or_update_user "$username" "$group" "$home_dir" "$expiry"; then
            log_action "USER_FAILED" "$username" "line $line_number"
            failure_count=$((failure_count + 1))
        fi
    done < "$csv_file"

    if [[ "$failure_count" -gt 0 ]]; then
        printf 'Completed with %s failed row(s). See %s.\n' "$failure_count" "$LOG_FILE" >&2
        return 1
    fi

    printf 'User creation/update completed successfully. See %s.\n' "$LOG_FILE"
}

shadow_expiry_days() {
    local username="$1"
    getent shadow "$username" | awk -F: '{print $8}'
}

is_account_expired() {
    local username="$1"
    local expiry_days
    local today_days

    expiry_days="$(shadow_expiry_days "$username")"
    today_days="$(( $(date +%s) / 86400 ))"

    [[ -n "$expiry_days" && "$expiry_days" =~ ^[0-9]+$ && "$expiry_days" -lt "$today_days" ]]
}

cleanup_expired_users() {
    local username
    local failure_count=0
    local deleted_count=0

    if ! getent group "$MANAGED_GROUP" >/dev/null; then
        log_action "CLEANUP" "system" "managed group does not exist; nothing to clean"
        printf 'Managed group %s does not exist. Nothing to clean.\n' "$MANAGED_GROUP"
        return 0
    fi

    while IFS=: read -r username _uid _gid _gecos _home _shell; do
        if [[ -z "$username" ]]; then
            continue
        fi

        if ! is_managed_user "$username"; then
            continue
        fi

        if is_account_expired "$username"; then
            log_action "EXPIRED_USER_FOUND" "$username" "eligible for deletion"
            if run_command "DELETE_EXPIRED_USER" "$username" userdel -r "$username"; then
                deleted_count=$((deleted_count + 1))
            else
                failure_count=$((failure_count + 1))
            fi
        else
            log_action "CLEANUP_SKIP_ACTIVE" "$username" "not expired"
        fi
    done < <(getent passwd)

    printf 'Cleanup finished. Deleted: %s. Failures: %s. See %s.\n' "$deleted_count" "$failure_count" "$LOG_FILE"

    if [[ "$failure_count" -gt 0 ]]; then
        return 1
    fi
}

main() {
    local command=""
    local csv_file=""

    if [[ "$#" -eq 0 ]]; then
        usage
        exit 1
    fi

    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --create)
                command="create"
                csv_file="${2:-}"
                if [[ -z "$csv_file" || "$csv_file" == --* ]]; then
                    printf 'ERROR: --create requires a CSV file.\n' >&2
                    exit 1
                fi
                shift 2
                ;;
            --cleanup-expired)
                command="cleanup"
                shift
                ;;
            --dry-run)
                DRY_RUN=1
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                printf 'ERROR: Unknown argument: %s\n' "$1" >&2
                usage
                exit 1
                ;;
        esac
    done

    require_root
    ensure_log_file

    case "$command" in
        create)
            process_csv "$csv_file"
            ;;
        cleanup)
            cleanup_expired_users
            ;;
        *)
            printf 'ERROR: Choose --create or --cleanup-expired.\n' >&2
            usage
            exit 1
            ;;
    esac
}

main "$@"
