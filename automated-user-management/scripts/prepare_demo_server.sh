#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
USER_MANAGER="${PROJECT_ROOT}/scripts/user_manager.sh"
RESET_DEMO_STATE=0

usage() {
    cat <<'USAGE'
Prepare an Ubuntu/Debian server for the Automated User Management demo.

Usage:
  sudo ./scripts/prepare_demo_server.sh
  sudo ./scripts/prepare_demo_server.sh --reset-demo-state
  ./scripts/prepare_demo_server.sh --help

Options:
  --reset-demo-state   Remove previous project users, timer files, installed script, and log.
                       This only deletes users from the managed_users group.
  --help               Show this help message.
USAGE
}

require_root() {
    if [[ "${EUID}" -ne 0 ]]; then
        printf 'ERROR: Run this script with sudo.\n' >&2
        exit 1
    fi
}

detect_supported_os() {
    if [[ ! -r /etc/os-release ]]; then
        printf 'ERROR: Cannot read /etc/os-release. Use Ubuntu or Debian.\n' >&2
        exit 1
    fi

    # shellcheck disable=SC1091
    . /etc/os-release

    case "${ID:-}" in
        ubuntu|debian)
            printf 'Detected supported OS: %s %s\n' "${PRETTY_NAME:-$ID}" "${VERSION_ID:-}"
            ;;
        *)
            printf 'ERROR: Unsupported OS: %s. Use Ubuntu or Debian.\n' "${PRETTY_NAME:-unknown}" >&2
            exit 1
            ;;
    esac
}

install_packages() {
    printf 'Installing required packages...\n'
    apt-get update
    apt-get install -y bash passwd openssh-client tree coreutils util-linux
}

verify_required_commands() {
    local commands=(
        awk
        bash
        chage
        chmod
        chown
        date
        getent
        groupadd
        groupdel
        id
        install
        ssh-keygen
        systemctl
        useradd
        userdel
        usermod
    )
    local command_name
    local missing=0

    printf 'Verifying required commands...\n'
    for command_name in "${commands[@]}"; do
        if command -v "$command_name" >/dev/null 2>&1; then
            printf '  OK: %s\n' "$command_name"
        else
            printf '  MISSING: %s\n' "$command_name" >&2
            missing=1
        fi
    done

    if [[ "$missing" -ne 0 ]]; then
        printf 'ERROR: One or more required commands are missing.\n' >&2
        exit 1
    fi
}

reset_demo_state() {
    local user

    printf 'Resetting previous demo state...\n'

    if getent group managed_users >/dev/null; then
        for user in $(getent group managed_users | awk -F: '{print $4}' | tr ',' ' '); do
            if [[ -n "$user" ]]; then
                printf '  Removing managed demo user: %s\n' "$user"
                userdel -r "$user" 2>/dev/null || true
            fi
        done
    fi

    systemctl disable --now user-cleanup.timer 2>/dev/null || true
    rm -f /etc/systemd/system/user-cleanup.service /etc/systemd/system/user-cleanup.timer
    systemctl daemon-reload 2>/dev/null || true

    rm -f /usr/local/bin/user_manager.sh
    rm -f /var/log/user_manager.log

    groupdel managed_users 2>/dev/null || true
    groupdel students 2>/dev/null || true
    groupdel interns 2>/dev/null || true
    groupdel labusers 2>/dev/null || true
    groupdel research 2>/dev/null || true

    printf 'Demo state reset completed.\n'
}

prepare_project_files() {
    if [[ ! -f "$USER_MANAGER" ]]; then
        printf 'ERROR: Cannot find user manager script at %s\n' "$USER_MANAGER" >&2
        exit 1
    fi

    chmod +x "$USER_MANAGER"
    bash -n "$USER_MANAGER"
    printf 'User manager script is executable and passed bash syntax check.\n'
}

print_next_steps() {
    cat <<EOF

Server is ready for the demo.

Next commands:
  cd ${PROJECT_ROOT}
  ./scripts/user_manager.sh --help
  sudo ./scripts/user_manager.sh --create users.csv --dry-run
  sudo ./scripts/user_manager.sh --create users.csv

Then record checks:
  id student01
  getent group managed_users
  sudo stat -c '%U %G %a %n' /home/student01
  sudo ls -la /home/student01/.ssh
  sudo chage -l student01
  sudo tail -n 30 /var/log/user_manager.log
EOF
}

main() {
    while [[ "$#" -gt 0 ]]; do
        case "$1" in
            --reset-demo-state)
                RESET_DEMO_STATE=1
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
    detect_supported_os

    if [[ "$RESET_DEMO_STATE" -eq 1 ]]; then
        reset_demo_state
    fi

    install_packages
    verify_required_commands
    prepare_project_files
    print_next_steps
}

main "$@"
