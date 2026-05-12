# Automated User Management System

A Bash-based Linux administration project for Ubuntu/Debian systems. It reads user records from a CSV file, creates or updates managed Linux accounts, generates SSH keys, applies password expiry rules, logs all actions, and provides a weekly systemd timer for cleanup of expired managed accounts.

This project is designed for a university assignment and should be tested in a VM.

## Concepts Used

- Bash scripting with functions, validation, and command-line arguments
- Linux users and groups
- File ownership and permissions
- Password/account expiry management with `chage`
- SSH key generation with `ssh-keygen`
- Logging to `/var/log/user_manager.log`
- Process automation using systemd services and timers

## Project Structure

```text
automated-user-management/
├── README.md
├── users.csv
├── scripts/
│   └── user_manager.sh
├── systemd/
│   ├── user-cleanup.service
│   └── user-cleanup.timer
├── tests/
│   └── test_commands.md
├── reports/
│   └── test_report.md
└── logs/
    └── sample_user_manager.log
```

## Safety Design

- The script requires root privileges for create and cleanup operations.
- It creates and uses a special group named `managed_users`.
- Cleanup deletes only users who are members of `managed_users`.
- Existing users that are not members of `managed_users` are skipped.
- `--dry-run` prints and logs planned actions without changing accounts.
- Dangerous actions such as user deletion are logged.
- The script is idempotent: running it again updates managed users instead of creating duplicates.

## CSV Format

The CSV file must use four columns:

```csv
username,group,home,expiry
student01,students,/home/student01,2026-12-31
student02,students,/home/student02,2026-12-31
```

Rules:

- The first row is a header and is skipped.
- Usernames and group names must be lowercase Linux-style names.
- Home directories must be under `/home`.
- Expiry dates must use `YYYY-MM-DD`.
- Simple CSV is expected; quoted commas are not supported.

## Fresh Ubuntu VM Commands

Install required tools:

```bash
sudo apt update
sudo apt install -y bash passwd openssh-client systemd
```

Enter the project and make the script executable:

```bash
cd automated-user-management
chmod +x scripts/user_manager.sh
```

Show help:

```bash
./scripts/user_manager.sh --help
```

Run a dry-run create:

```bash
sudo ./scripts/user_manager.sh --create users.csv --dry-run
```

Create or update users:

```bash
sudo ./scripts/user_manager.sh --create users.csv
```

Run cleanup in dry-run mode:

```bash
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
```

Run cleanup for real:

```bash
sudo ./scripts/user_manager.sh --cleanup-expired
```

## Check Created Users

```bash
getent group managed_users
id student01
getent passwd student01
```

## Check Home Permissions

```bash
sudo stat -c '%U %G %a %n' /home/student01
```

Expected example:

```text
student01 students 700 /home/student01
```

## Check SSH Keys

```bash
sudo ls -la /home/student01/.ssh
sudo stat -c '%U %G %a %n' /home/student01/.ssh /home/student01/.ssh/id_ed25519 /home/student01/.ssh/id_ed25519.pub
```

Expected permissions:

- `.ssh`: `700`
- `id_ed25519`: `600`
- `id_ed25519.pub`: `644`

## Check Password Expiry

```bash
sudo chage -l student01
```

Look for:

- Maximum number of days between password change: `90`
- Number of days of warning before password expires: `7`
- Account expires: date from `users.csv`

## Check Logs

```bash
sudo tail -n 50 /var/log/user_manager.log
```

Log format:

```text
YYYY-MM-DD HH:MM:SS | action=ACTION | username=USERNAME | result=RESULT
```

## Install the Systemd Timer

Copy the script to the system path required by the service:

```bash
sudo cp scripts/user_manager.sh /usr/local/bin/user_manager.sh
sudo chmod +x /usr/local/bin/user_manager.sh
```

Copy the service and timer:

```bash
sudo cp systemd/user-cleanup.service /etc/systemd/system/
sudo cp systemd/user-cleanup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
```

Check the timer:

```bash
systemctl list-timers user-cleanup.timer
sudo systemctl status user-cleanup.timer
```

Run the cleanup service manually:

```bash
sudo systemctl start user-cleanup.service
sudo systemctl status user-cleanup.service
```

## Evidence and Screenshots for the Test Report

Use these commands while taking screenshots:

```bash
sudo ./scripts/user_manager.sh --create users.csv
getent group managed_users
id student01
sudo stat -c '%U %G %a %n' /home/student01
sudo ls -la /home/student01/.ssh
sudo chage -l student01
sudo tail -n 50 /var/log/user_manager.log
systemctl list-timers user-cleanup.timer
sudo systemctl status user-cleanup.timer
```

Suggested screenshots:

- Successful user creation command
- `/var/log/user_manager.log`
- `id student01`
- Home directory permissions
- SSH key permissions
- `chage -l student01`
- systemd timer status

## Cleanup and Uninstall

Remove only users managed by this project:

```bash
for user in $(getent group managed_users | awk -F: '{print $4}' | tr ',' ' '); do
    sudo userdel -r "$user" 2>/dev/null || true
done
```

Remove project groups after users are removed:

```bash
sudo groupdel managed_users 2>/dev/null || true
sudo groupdel students 2>/dev/null || true
sudo groupdel interns 2>/dev/null || true
sudo groupdel labusers 2>/dev/null || true
sudo groupdel research 2>/dev/null || true
```

Disable and remove systemd files:

```bash
sudo systemctl disable --now user-cleanup.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/user-cleanup.service /etc/systemd/system/user-cleanup.timer
sudo systemctl daemon-reload
```

Remove installed script and log if no longer needed:

```bash
sudo rm -f /usr/local/bin/user_manager.sh
sudo rm -f /var/log/user_manager.log
```

## Assumptions

- The project is tested on an Ubuntu/Debian VM, not on a production machine.
- The `openssh-client` package is available for `ssh-keygen`.
- CSV values do not contain quoted commas.
- The script should not manage or modify existing users unless they already belong to `managed_users`.
