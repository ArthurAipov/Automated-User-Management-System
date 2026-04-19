# Automated User Management System

A Bash-based solution for managing Linux user accounts from a CSV file, with
SSH key generation, password-policy enforcement, and a weekly systemd-timer
cleanup of expired accounts.

---

## Repository layout

```
.
├── manage_users.sh        # Main management script
├── cleanup_expired.sh     # Thin wrapper called by the systemd service
├── users.csv              # Sample CSV with 12 test users
├── systemd/
│   ├── user-cleanup.service   # Systemd service unit
│   └── user-cleanup.timer     # Systemd timer unit (weekly, Monday 02:00)
├── user_management.log    # Created at runtime; all actions are appended here
└── test_report.md         # Full test report (12 test cases, 12 users)
```

---

## CSV format

```
username,group,home_directory,expiry_date
alice,developers,/home/alice,2027-01-01
bob,developers,/home/bob,2027-06-30
```

* **username** – Linux account name.
* **group** – Primary group (created automatically if it doesn't exist).
* **home_directory** – Absolute path; created with `mode 700`.
* **expiry_date** – Account expiry in `YYYY-MM-DD` format.

The first line must be the header row shown above.

---

## Requirements

| Dependency | Minimum version | Notes |
|------------|-----------------|-------|
| Bash | 4.x | `set -euo pipefail` |
| `useradd` / `userdel` | any | from `shadow-utils` |
| `chage` | any | password aging |
| `ssh-keygen` | any | ed25519 key pair generation |
| `systemd` | 229+ | for timer support |

The scripts must be run as **root** (or via `sudo`) for all commands except
`list`.

---

## Quick start

### 1. Clone and make executable

```bash
git clone https://github.com/ArthurAipov/Automated-User-Management-System.git
cd Automated-User-Management-System
chmod +x manage_users.sh cleanup_expired.sh
```

### 2. Create users

```bash
sudo ./manage_users.sh create --csv users.csv
```

What happens:
* Groups are created if they don't already exist.
* Each user is created with `useradd`, home directory set to `mode 700`.
* Password is **locked** (`passwd -l`) – users must log in via SSH key.
* Password aging is configured with `chage` (max 90 days, min 7, warn 14).
* Account expiry is set to the date in the CSV.
* An **ed25519 SSH key pair** is generated in `~/.ssh/` and the public key is
  added to `~/.ssh/authorized_keys`.
* Every action is appended to `user_management.log`.

### 3. List users

```bash
./manage_users.sh list --csv users.csv   # no sudo required
```

Shows each user's status (exists / not), expiry date, and whether the account
is expired.

### 4. Remove expired accounts

```bash
sudo ./manage_users.sh cleanup --csv users.csv
```

Iterates the CSV, compares today's date against each expiry date, and removes
any account that has expired.

### 5. Delete all users in the CSV

```bash
sudo ./manage_users.sh delete --csv users.csv
```

---

## Systemd timer (weekly cleanup)

### Install

```bash
# Copy scripts to a stable location
sudo mkdir -p /opt/user-management
sudo cp manage_users.sh cleanup_expired.sh users.csv /opt/user-management/
sudo chmod +x /opt/user-management/manage_users.sh \
              /opt/user-management/cleanup_expired.sh

# Install systemd units
sudo cp systemd/user-cleanup.service /etc/systemd/system/
sudo cp systemd/user-cleanup.timer   /etc/systemd/system/

# Enable and start the timer
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
```

### Verify

```bash
systemctl list-timers user-cleanup.timer
journalctl -u user-cleanup.service
```

The timer fires every **Monday at 02:00** local time.  If the system was
offline at that time, systemd will run the job as soon as it comes back up
(within 6 hours of the missed trigger, thanks to `Persistent=true`).

---

## Logging

All management actions are appended to `user_management.log` (in the same
directory as `manage_users.sh`, or `/opt/user-management/` when deployed).

Format:

```
YYYY-MM-DD HH:MM:SS [LEVEL] message
```

Levels: `INFO`, `OK`, `WARN`, `ERROR`.

---

## Password policy summary

| Setting | Value |
|---------|-------|
| Maximum password age | 90 days |
| Minimum password age | 7 days |
| Password expiry warning | 14 days before expiry |
| Account expiry | Per-user, from CSV |
| Initial password state | Locked (SSH-key login only) |

---

## Security notes

* Home directories are created with permissions `700` (owner read/write/execute
  only).
* SSH key pairs use the `ed25519` algorithm.
* `~/.ssh` has permissions `700`; `authorized_keys` and the private key have
  permissions `600`.
* Passwords are locked immediately after account creation.

---

## Test report

See [`test_report.md`](test_report.md) for 12 detailed test cases covering
user creation, SSH key generation, password policy, expired-account cleanup,
idempotency, error handling, and the systemd timer.