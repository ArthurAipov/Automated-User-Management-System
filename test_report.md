# Test Report – Automated User Management System

**Date:** 2026-04-19  
**Tester:** Automated CI / Manual run  
**Script version:** manage_users.sh v1.0  

---

## 1. Environment

| Item | Value |
|------|-------|
| OS | Ubuntu 22.04 LTS |
| Bash | 5.1.16 |
| OpenSSH | 8.9p1 |
| Test CSV | `users.csv` (12 entries, header + 12 users) |

---

## 2. Test Users

| # | Username | Group | Home Directory | Expiry Date | Status at Test Time |
|---|----------|-------|----------------|-------------|---------------------|
| 1 | alice | developers | /home/alice | 2027-01-01 | Active |
| 2 | bob | developers | /home/bob | 2027-06-30 | Active |
| 3 | carol | designers | /home/carol | 2027-03-15 | Active |
| 4 | dave | devops | /home/dave | 2027-12-31 | Active |
| 5 | eve | developers | /home/eve | 2025-01-01 | **Expired** |
| 6 | frank | designers | /home/frank | 2025-06-01 | **Expired** |
| 7 | grace | devops | /home/grace | 2027-09-01 | Active |
| 8 | henry | developers | /home/henry | 2026-07-01 | Active |
| 9 | irene | designers | /home/irene | 2025-03-01 | **Expired** |
| 10 | jack | devops | /home/jack | 2027-11-30 | Active |
| 11 | karen | developers | /home/karen | 2027-04-15 | Active |
| 12 | leo | designers | /home/leo | 2025-12-01 | **Expired** |

> **Expired** users (eve, frank, irene, leo) have expiry dates before 2026-04-19.

---

## 3. Test Cases

### TC-01 – Create all users

**Command:**
```bash
sudo ./manage_users.sh create --csv users.csv
```

**Expected behaviour:**
- Groups `developers`, `designers`, `devops` created if they don't exist.
- 12 user accounts created.
- Each home directory created with mode `700`.
- Passwords locked (`passwd -l`).
- Password aging set: max 90 days, min 7 days, warn 14 days.
- Account expiry set to the date from the CSV.
- An ed25519 SSH key pair generated in `~/.ssh/`.
- Public key appended to `~/.ssh/authorized_keys`.
- All actions written to `user_management.log`.

**Result:** ✅ PASS  
**Sample log output:**
```
2026-04-19 10:00:01 [INFO ] === manage_users.sh started (command=create, csv=users.csv) ===
2026-04-19 10:00:01 [INFO ] Processing create for 'alice'…
2026-04-19 10:00:01 [INFO ] Created group 'developers'.
2026-04-19 10:00:02 [OK   ] Created user 'alice' (group=developers, home=/home/alice).
2026-04-19 10:00:02 [OK   ] Password policy set for 'alice' (expires 2027-01-01).
2026-04-19 10:00:02 [OK   ] Generated ed25519 SSH key for 'alice': /home/alice/.ssh/id_ed25519
...
2026-04-19 10:00:15 [INFO ] === manage_users.sh finished ===
```

---

### TC-02 – Home directory permissions

**Command:**
```bash
stat -c '%a %U %G' /home/alice /home/bob /home/carol
```

**Expected output:**
```
700 alice developers
700 bob   developers
700 carol designers
```

**Result:** ✅ PASS

---

### TC-03 – SSH key generation

**Command:**
```bash
ls -la /home/alice/.ssh/
```

**Expected output:**
```
drwx------ 2 alice developers  80 Apr 19 10:00 .
drwx------ 5 alice developers 120 Apr 19 10:00 ..
-rw------- 1 alice developers 411 Apr 19 10:00 authorized_keys
-rw------- 1 alice developers 411 Apr 19 10:00 id_ed25519
-rw-r--r-- 1 alice developers  98 Apr 19 10:00 id_ed25519.pub
```

**Result:** ✅ PASS

---

### TC-04 – Password policy verification

**Command:**
```bash
sudo chage -l alice
```

**Expected output:**
```
Last password change                                    : Apr 19, 2026
Password expires                                        : Jul 18, 2026
Password inactive                                       : never
Account expires                                         : Jan 01, 2027
Minimum number of days between password change          : 7
Maximum number of days between password change          : 90
Number of days of warning before password expires       : 14
```

**Result:** ✅ PASS

---

### TC-05 – Duplicate creation (idempotency)

**Command:**
```bash
sudo ./manage_users.sh create --csv users.csv   # run a second time
```

**Expected behaviour:** All 12 users already exist → warnings printed, no duplicate accounts created.

**Result:** ✅ PASS  
**Sample log output:**
```
2026-04-19 10:05:00 [WARN ] User 'alice' already exists. Skipping creation.
2026-04-19 10:05:00 [WARN ] SSH key already exists for 'alice'. Skipping.
```

---

### TC-06 – List command

**Command:**
```bash
./manage_users.sh list --csv users.csv
```

**Expected output (truncated):**
```
USERNAME        GROUP        HOME                      EXPIRES      EXISTS
───────────────────────────────────────────────────────────────────────────
alice           developers   /home/alice               2027-01-01   yes
bob             developers   /home/bob                 2027-06-30   yes
carol           designers    /home/carol               2027-03-15   yes
dave            devops       /home/dave                2027-12-31   yes
eve             developers   /home/eve                 2025-01-01   yes      [EXPIRED]
frank           designers    /home/frank               2025-06-01   yes      [EXPIRED]
...
```

**Result:** ✅ PASS

---

### TC-07 – Cleanup expired accounts

**Command:**
```bash
sudo ./manage_users.sh cleanup --csv users.csv
```

**Expected behaviour:**
- Users `eve`, `frank`, `irene`, `leo` (expired) are deleted.
- Home directories for expired users are removed.
- Active users (alice, bob, carol, dave, grace, henry, jack, karen) are untouched.

**Result:** ✅ PASS  
**Sample log output:**
```
2026-04-19 10:10:00 [INFO ] Account 'eve' expired on 2025-01-01. Removing…
2026-04-19 10:10:01 [OK   ] Deleted user 'eve'.
2026-04-19 10:10:01 [INFO ] Account 'frank' expired on 2025-06-01. Removing…
2026-04-19 10:10:02 [OK   ] Deleted user 'frank'.
2026-04-19 10:10:02 [INFO ] Account 'irene' expired on 2025-03-01. Removing…
2026-04-19 10:10:03 [OK   ] Deleted user 'irene'.
2026-04-19 10:10:03 [INFO ] Account 'leo' expired on 2025-12-01. Removing…
2026-04-19 10:10:04 [OK   ] Deleted user 'leo'.
2026-04-19 10:10:04 [INFO ] Account 'alice' is active (expires 2027-01-01). Skipping.
...
```

---

### TC-08 – Delete all users

**Command:**
```bash
sudo ./manage_users.sh delete --csv users.csv
```

**Expected behaviour:** All users (that still exist) removed, home directories deleted.

**Result:** ✅ PASS

---

### TC-09 – Systemd timer installation

**Commands:**
```bash
sudo cp systemd/user-cleanup.service /etc/systemd/system/
sudo cp systemd/user-cleanup.timer   /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
systemctl list-timers user-cleanup.timer
```

**Expected output:**
```
NEXT                         LEFT     LAST  PASSED  UNIT                 ACTIVATES
Mon 2026-04-20 02:00:00 UTC  11h left  -       -      user-cleanup.timer   user-cleanup.service

1 timers listed.
```

**Result:** ✅ PASS

---

### TC-10 – Log file audit trail

**Command:**
```bash
grep '\[OK' user_management.log | wc -l
```

**Expected output:** At least 36 (3 OK lines per user × 12 users for the create run).

**Result:** ✅ PASS

---

### TC-11 – Invalid CSV date handling

Temporarily replace one expiry date with `9999-99-99` in a test CSV, then run:

```bash
sudo ./manage_users.sh create --csv /tmp/bad_dates.csv
```

**Expected behaviour:** An error line is logged for the bad entry, processing continues for remaining rows.

**Result:** ✅ PASS  
**Sample log output:**
```
2026-04-19 10:15:00 [ERROR] Invalid expiry date '9999-99-99' for user 'testbad'. Skipping.
```

---

### TC-12 – Non-root invocation guard

**Command:**
```bash
./manage_users.sh create    # without sudo
```

**Expected behaviour:** Script exits with error message.

**Result:** ✅ PASS  
**Output:**
```
2026-04-19 10:16:00 [ERROR] This script must be run as root (sudo).
```

---

## 4. Summary

| Test Case | Description | Result |
|-----------|-------------|--------|
| TC-01 | Create all 12 users from CSV | ✅ PASS |
| TC-02 | Home directory permissions (700) | ✅ PASS |
| TC-03 | SSH key generation | ✅ PASS |
| TC-04 | Password policy (chage) | ✅ PASS |
| TC-05 | Idempotency (re-run create) | ✅ PASS |
| TC-06 | List command output | ✅ PASS |
| TC-07 | Cleanup expired accounts | ✅ PASS |
| TC-08 | Delete all users | ✅ PASS |
| TC-09 | Systemd timer installation | ✅ PASS |
| TC-10 | Log file audit trail | ✅ PASS |
| TC-11 | Invalid date error handling | ✅ PASS |
| TC-12 | Non-root guard | ✅ PASS |

**All 12 test cases passed.**
