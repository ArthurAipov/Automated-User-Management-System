# Cloud Server Demo Setup

Этот гайд готовит Ubuntu/Debian cloud server к записи демо. Все команды `sudo ./scripts/user_manager.sh ...` нужно выполнять на сервере, а экран можно записывать с Mac через SSH terminal.

## 1. Требования к серверу

Подойдет временный VPS:

- Ubuntu 22.04 / 24.04 или Debian 12
- 1 CPU
- 1 GB RAM или больше
- доступ по SSH
- желательно одноразовый тестовый сервер, не production

## 2. Подключиться с Mac

```bash
ssh ubuntu@SERVER_IP
```

Или, если сервер выдан с root-доступом:

```bash
ssh root@SERVER_IP
```

Покажи в начале демо, что это Linux server:

```bash
hostnamectl
whoami
pwd
```

## 3. Передать проект на сервер

На Mac из папки проекта:

```bash
cd /Users/arturaipov/Downloads/Automated-User-Management-System
scp -r automated-user-management ubuntu@SERVER_IP:/home/ubuntu/
```

Если подключение идет под root:

```bash
scp -r automated-user-management root@SERVER_IP:/root/
```

## 4. Подготовить сервер

На сервере:

```bash
cd automated-user-management
chmod +x scripts/*.sh
sudo ./scripts/prepare_demo_server.sh
```

Если ты уже запускал демо на этом сервере и хочешь начать с чистого состояния:

```bash
sudo ./scripts/prepare_demo_server.sh --reset-demo-state
```

Флаг `--reset-demo-state` удаляет только пользователей из группы `managed_users`, отключает demo timer, удаляет установленный `/usr/local/bin/user_manager.sh` и лог `/var/log/user_manager.log`.

## 5. Проверка перед записью

```bash
./scripts/user_manager.sh --help
sudo ./scripts/user_manager.sh --create users.csv --dry-run
```

Если dry-run показывает будущие действия, сервер готов.

## 6. Команды для демо

```bash
tree . 2>/dev/null || find . -maxdepth 3 -type f | sort
cat users.csv
./scripts/user_manager.sh --help
sudo ./scripts/user_manager.sh --create users.csv --dry-run
sudo ./scripts/user_manager.sh --create users.csv
id student01
getent group managed_users
getent passwd student01
sudo stat -c '%U %G %a %n' /home/student01
sudo ls -la /home/student01/.ssh
sudo stat -c '%U %G %a %n' /home/student01/.ssh /home/student01/.ssh/id_ed25519 /home/student01/.ssh/id_ed25519.pub
sudo chage -l student01
sudo tail -n 30 /var/log/user_manager.log
```

## 7. Systemd timer demo

```bash
sudo cp scripts/user_manager.sh /usr/local/bin/user_manager.sh
sudo chmod +x /usr/local/bin/user_manager.sh
sudo cp systemd/user-cleanup.service systemd/user-cleanup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
systemctl list-timers user-cleanup.timer
sudo systemctl status user-cleanup.timer
```

## 8. Cleanup demo

Чтобы показать реальное удаление expired account:

```bash
printf 'username,group,home,expiry\nexpired01,students,/home/expired01,2020-01-01\n' > /tmp/expired-users.csv
cat /tmp/expired-users.csv
sudo ./scripts/user_manager.sh --create /tmp/expired-users.csv
id expired01
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
sudo ./scripts/user_manager.sh --cleanup-expired
getent passwd expired01 || echo 'expired01 removed successfully'
sudo tail -n 30 /var/log/user_manager.log
```

## 9. Что сказать в видео

В начале:

> I am running this demo on a temporary Ubuntu cloud server through SSH from my Mac. This gives the project a real Linux environment with user management and systemd support.

В конце:

> The script creates users from CSV, adds them to managed_users, configures home permissions, SSH keys, password expiry, and logs all actions. Cleanup is safe because it only deletes expired users from managed_users. The systemd timer runs cleanup weekly.

## 10. Очистка после демо

На сервере:

```bash
sudo ./scripts/prepare_demo_server.sh --reset-demo-state
```

Если сервер одноразовый, можно просто удалить VPS в панели облачного провайдера.
