# Demo Commands Numbered

Файл для записи демо. Иди сверху вниз и вводи команды по одной. Команды рассчитаны на запуск на Ubuntu cloud server под `root`.

Если ты не `root`, добавляй `sudo` перед командами, которые меняют пользователей, systemd или `/var/log`.

## До записи: очистить старое состояние

0 команда:

```bash
ssh root@185.207.65.5
```

Описание: подключиться с Mac к Ubuntu cloud server по SSH.

0.1 команда:

```bash
cd ~/Automated-User-Management-System/automated-user-management
```

Описание: перейти в папку проекта на сервере.

0.2 команда:

```bash
./scripts/prepare_demo_server.sh --reset-demo-state
```

Описание: очистить старых demo users, timer, установленный script и log. Скрипт удаляет только пользователей из `managed_users`.

0.3 команда:

```bash
clear
```

Описание: очистить терминал перед стартом записи.

## Основная запись демо

1 команда:

```bash
hostnamectl
```

Описание: показать, что проект запускается на реальном Ubuntu Linux server.

2 команда:

```bash
whoami
```

Описание: показать текущего пользователя. Если вывод `root`, команды можно выполнять без `sudo`.

3 команда:

```bash
pwd
```

Описание: показать текущую директорию перед переходом в проект.

4 команда:

```bash
cd ~/Automated-User-Management-System/automated-user-management
```

Описание: перейти в директорию проекта.

5 команда:

```bash
tree . 2>/dev/null || find . -maxdepth 3 -type f | sort
```

Описание: показать структуру проекта: README, CSV, Bash script, systemd files, tests, reports, logs.

6 команда:

```bash
cat users.csv
```

Описание: показать CSV input file с 10+ test users и колонками `username,group,home,expiry`.

7 команда:

```bash
./scripts/user_manager.sh --help
```

Описание: показать, что script поддерживает `--create`, `--cleanup-expired`, `--dry-run` и `--help`.

8 команда:

```bash
./scripts/user_manager.sh --create users.csv --dry-run
```

Описание: показать safe dry-run mode. Скрипт показывает будущие действия, но не меняет систему.

9 команда:

```bash
./scripts/user_manager.sh --create users.csv
```

Описание: создать или обновить Linux users из CSV.

10 команда:

```bash
id student01
```

Описание: проверить, что `student01` создан и состоит в primary group `students` и management group `managed_users`.

11 команда:

```bash
getent group managed_users
```

Описание: показать всех пользователей, которыми управляет проект. Cleanup работает только с этой группой.

12 команда:

```bash
getent passwd student01
```

Описание: проверить Linux account record: home directory `/home/student01` и shell `/bin/bash`.

13 команда:

```bash
stat -c '%U %G %a %n' /home/student01
```

Описание: проверить home directory ownership и permissions. Ожидаемо: `student01 students 700 /home/student01`.

14 команда:

```bash
ls -la /home/student01/.ssh
```

Описание: показать, что SSH key pair создан в `.ssh`.

15 команда:

```bash
stat -c '%U %G %a %n' /home/student01/.ssh /home/student01/.ssh/id_ed25519 /home/student01/.ssh/id_ed25519.pub
```

Описание: проверить SSH permissions. Ожидаемо: `.ssh` = `700`, private key = `600`, public key = `644`.

16 команда:

```bash
chage -l student01
```

Описание: проверить password policy и account expiry. Ожидаемо: max password age `90`, warning `7`, account expires из CSV.

17 команда:

```bash
tail -n 30 /var/log/user_manager.log
```

Описание: показать log file, где записаны user management actions.

18 команда:

```bash
./scripts/user_manager.sh --create users.csv
```

Описание: повторно запустить create/update для проверки idempotency. Повторный запуск не должен ломать существующих пользователей.

19 команда:

```bash
tail -n 20 /var/log/user_manager.log
```

Описание: показать, что повторный запуск сделал `UPDATE_USER` и `SSH_KEY_EXISTS`, а не создал дубликаты.

20 команда:

```bash
cp scripts/user_manager.sh /usr/local/bin/user_manager.sh
```

Описание: установить script в путь, который использует systemd service.

21 команда:

```bash
chmod +x /usr/local/bin/user_manager.sh
```

Описание: сделать installed script исполняемым.

22 команда:

```bash
cp systemd/user-cleanup.service systemd/user-cleanup.timer /etc/systemd/system/
```

Описание: установить systemd service и timer.

23 команда:

```bash
systemctl daemon-reload
```

Описание: обновить systemd после добавления новых unit files.

24 команда:

```bash
systemctl enable --now user-cleanup.timer
```

Описание: включить weekly cleanup timer и запустить его ожидание.

25 команда:

```bash
systemctl list-timers user-cleanup.timer
```

Описание: показать, когда timer запустит cleanup в следующий раз.

26 команда:

```bash
systemctl status user-cleanup.timer
```

Описание: показать, что timer active.

27 команда:

```bash
printf 'username,group,home,expiry\nexpired01,students,/home/expired01,2020-01-01\n' > /tmp/expired-users.csv
```

Описание: создать отдельный CSV с expired test user для демонстрации cleanup.

28 команда:

```bash
cat /tmp/expired-users.csv
```

Описание: показать, что у test user старая expiry date `2020-01-01`.

29 команда:

```bash
./scripts/user_manager.sh --create /tmp/expired-users.csv
```

Описание: создать expired user, который тоже принадлежит проекту.

30 команда:

```bash
id expired01
```

Описание: показать, что expired user создан и входит в `managed_users`.

31 команда:

```bash
./scripts/user_manager.sh --cleanup-expired --dry-run
```

Описание: безопасно показать, что cleanup удалил бы `expired01`, но пока без изменений.

32 команда:

```bash
./scripts/user_manager.sh --cleanup-expired
```

Описание: реально удалить expired users. Скрипт удаляет только expired members of `managed_users`.

33 команда:

```bash
getent passwd expired01 || echo 'expired01 removed successfully'
```

Описание: доказать, что `expired01` удален из системы.

34 команда:

```bash
tail -n 40 /var/log/user_manager.log
```

Описание: показать cleanup log: active users skipped, expired user found, deletion successful.

## Финальная фраза

Скажи:

> This completes the demo. The system creates and updates users from a CSV file, configures groups, home directories, SSH keys and password expiry policies, logs every action, runs weekly cleanup using systemd, and safely deletes only expired accounts that belong to the managed_users group.

## После записи: очистка сервера

35 команда:

```bash
./scripts/prepare_demo_server.sh --reset-demo-state
```

Описание: очистить demo users, timer, installed script и log после записи.
