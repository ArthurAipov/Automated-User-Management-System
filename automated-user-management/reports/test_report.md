# Test Report: Automated User Management System

## Test Environment

- Operating system: Ubuntu/Debian Linux VM
- Shell: Bash
- Required privileges: root for create, update, cleanup, and log writing
- Project directory: `automated-user-management`
- Log file: `/var/log/user_manager.log`
- Management group: `managed_users`

## Test CSV

The project includes `users.csv` with 11 test users:

```csv
username,group,home,expiry
student01,students,/home/student01,2026-12-31
student02,students,/home/student02,2026-12-31
student03,students,/home/student03,2026-12-31
student04,students,/home/student04,2026-12-31
student05,students,/home/student05,2026-12-31
intern01,interns,/home/intern01,2026-09-30
intern02,interns,/home/intern02,2026-09-30
labuser01,labusers,/home/labuser01,2026-08-15
labuser02,labusers,/home/labuser02,2026-08-15
research01,research,/home/research01,2027-01-31
research02,research,/home/research02,2027-01-31
```

## Evidence Placeholders

[Screenshot: successful user creation]

[Screenshot: log file]

[Screenshot: systemd timer status]

[Screenshot: home directory permissions]

[Screenshot: SSH key permissions]

## Test Cases

| # | Test case | Commands used | Expected result | Actual result |
|---|---|---|---|---|
| 1 | Create users from CSV | `sudo ./scripts/user_manager.sh --create users.csv` | Users, groups, homes, SSH keys, and policies are created. | Pending screenshot/evidence |
| 2 | Re-run script to test idempotency | `sudo ./scripts/user_manager.sh --create users.csv` | Existing managed users are updated without duplicate users or broken homes. | Pending screenshot/evidence |
| 3 | Invalid username | Append `BadUser,students,/home/BadUser,2026-12-31`, then run create. | Row is rejected and logged as `INVALID_USERNAME`. | Pending screenshot/evidence |
| 4 | Invalid date | Append `student99,students,/home/student99,2026-99-99`, then run create. | Row is rejected and logged as `INVALID_EXPIRY`. | Pending screenshot/evidence |
| 5 | Missing CSV file | `sudo ./scripts/user_manager.sh --create missing.csv` | Script exits with an error and logs the missing file. | Pending screenshot/evidence |
| 6 | Dry-run mode | `sudo ./scripts/user_manager.sh --create users.csv --dry-run` | Planned actions are printed and logged; no accounts are changed. | Pending screenshot/evidence |
| 7 | SSH key generation | `sudo ls -la /home/student01/.ssh` | `id_ed25519` and `id_ed25519.pub` exist with correct permissions. | Pending screenshot/evidence |
| 8 | Home directory permissions | `sudo stat -c '%U %G %a %n' /home/student01` | Owner is `student01`, group is `students`, permissions are `700`. | Pending screenshot/evidence |
| 9 | Password expiry policy | `sudo chage -l student01` | Max password age is 90 days, warning is 7 days, expiry matches CSV. | Pending screenshot/evidence |
| 10 | Cleanup expired accounts | Create `expired01` with old expiry, then run cleanup. | Only expired members of `managed_users` are deleted with `userdel -r`. | Pending screenshot/evidence |
| 11 | Systemd timer status | `systemctl list-timers user-cleanup.timer` | Weekly timer is enabled and scheduled. | Pending screenshot/evidence |

## Commands Used

```bash
chmod +x scripts/user_manager.sh
sudo ./scripts/user_manager.sh --create users.csv --dry-run
sudo ./scripts/user_manager.sh --create users.csv
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
sudo tail -n 50 /var/log/user_manager.log
id student01
getent group managed_users
sudo stat -c '%U %G %a %n' /home/student01
sudo ls -la /home/student01/.ssh
sudo chage -l student01
systemctl list-timers user-cleanup.timer
```

## Notes

- Cleanup is intentionally limited to accounts that are members of `managed_users`.
- Existing users not in `managed_users` are skipped to avoid changing system or personal accounts.
- The script continues processing other rows when one CSV row fails validation.
