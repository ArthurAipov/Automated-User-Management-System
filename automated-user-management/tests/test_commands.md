# Test Commands

Run these commands in a fresh Ubuntu/Debian test VM. Use dry-run first if you want to verify the actions without changing accounts.

## Preparation

```bash
cd automated-user-management
chmod +x scripts/user_manager.sh
```

## Dry Run

```bash
sudo ./scripts/user_manager.sh --create users.csv --dry-run
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
```

## Create or Update Users

```bash
sudo ./scripts/user_manager.sh --create users.csv
```

## Verify Users and Groups

```bash
getent group managed_users
id student01
getent passwd student01
```

## Verify Home Directories

```bash
sudo stat -c '%U %G %a %n' /home/student01
sudo ls -la /home/student01/.ssh
sudo stat -c '%U %G %a %n' /home/student01/.ssh /home/student01/.ssh/id_ed25519 /home/student01/.ssh/id_ed25519.pub
```

## Verify Password Policy and Expiry

```bash
sudo chage -l student01
sudo chage -l intern01
```

## Verify Logging

```bash
sudo tail -n 50 /var/log/user_manager.log
```

## Invalid Username Test

```bash
cp users.csv /tmp/users-invalid-name.csv
printf 'BadUser,students,/home/BadUser,2026-12-31\n' | sudo tee -a /tmp/users-invalid-name.csv
sudo ./scripts/user_manager.sh --create /tmp/users-invalid-name.csv
sudo tail -n 20 /var/log/user_manager.log
```

## Invalid Date Test

```bash
cp users.csv /tmp/users-invalid-date.csv
printf 'student99,students,/home/student99,2026-99-99\n' | sudo tee -a /tmp/users-invalid-date.csv
sudo ./scripts/user_manager.sh --create /tmp/users-invalid-date.csv
sudo tail -n 20 /var/log/user_manager.log
```

## Missing CSV Test

```bash
sudo ./scripts/user_manager.sh --create missing.csv
```

## Cleanup Expired Accounts Test

Create a temporary expired managed user, then run cleanup.

```bash
printf 'expired01,students,/home/expired01,2020-01-01\n' | sudo tee /tmp/expired-users.csv
sudo sed -i '1i username,group,home,expiry' /tmp/expired-users.csv
sudo ./scripts/user_manager.sh --create /tmp/expired-users.csv
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
sudo ./scripts/user_manager.sh --cleanup-expired
getent passwd expired01 || echo 'expired01 removed'
```

## Systemd Timer Test

```bash
sudo cp scripts/user_manager.sh /usr/local/bin/user_manager.sh
sudo chmod +x /usr/local/bin/user_manager.sh
sudo cp systemd/user-cleanup.service systemd/user-cleanup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
systemctl list-timers user-cleanup.timer
sudo systemctl status user-cleanup.timer
```
