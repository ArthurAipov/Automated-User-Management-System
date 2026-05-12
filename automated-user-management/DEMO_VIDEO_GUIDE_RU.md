# Demo Video Guide: Automated User Management System

Этот сценарий можно использовать для записи демо-видео с Mac. Лучше всего записывать экран Mac, а команды выполнять в Ubuntu/Debian VM или через SSH в VM.

## 1. Что сказать в начале

Короткое вступление:

> Это демонстрация проекта Automated User Management System. Проект написан на Bash для Ubuntu/Debian Linux. Скрипт читает пользователей из CSV, создает или обновляет Linux-аккаунты, настраивает группы, домашние директории, SSH-ключи, password expiry policy, ведет логирование и использует systemd timer для еженедельной очистки expired accounts.

## 2. Подготовка записи на Mac

Открой запись экрана:

1. Нажми `Command + Shift + 5`.
2. Выбери запись всего экрана или выбранной области.
3. В `Options` включи микрофон, если нужен голос.
4. Нажми `Record`.

Можно записывать:

- окно Terminal на Mac с SSH в Ubuntu VM;
- окно UTM/VirtualBox с Ubuntu;
- окно Multipass shell.

## 3. Команды для демо

Перейди в проект:

```bash
cd automated-user-management
ls -R
```

Покажи структуру:

```bash
tree . 2>/dev/null || find . -maxdepth 3 -type f | sort
```

Покажи CSV:

```bash
cat users.csv
```

Покажи help:

```bash
./scripts/user_manager.sh --help
```

Покажи безопасный dry-run:

```bash
sudo ./scripts/user_manager.sh --create users.csv --dry-run
```

Создай пользователей:

```bash
sudo ./scripts/user_manager.sh --create users.csv
```

Проверь пользователя и группы:

```bash
id student01
getent group managed_users
getent passwd student01
```

Проверь домашнюю директорию:

```bash
sudo stat -c '%U %G %a %n' /home/student01
```

Проверь SSH-ключи:

```bash
sudo ls -la /home/student01/.ssh
sudo stat -c '%U %G %a %n' /home/student01/.ssh /home/student01/.ssh/id_ed25519 /home/student01/.ssh/id_ed25519.pub
```

Проверь password/account expiry policy:

```bash
sudo chage -l student01
```

Покажи лог:

```bash
sudo tail -n 30 /var/log/user_manager.log
```

Проверь идемпотентность:

```bash
sudo ./scripts/user_manager.sh --create users.csv
sudo tail -n 20 /var/log/user_manager.log
```

## 4. Проверка cleanup

Сначала dry-run:

```bash
sudo ./scripts/user_manager.sh --cleanup-expired --dry-run
```

Чтобы показать реальное удаление expired account, создай отдельный тестовый CSV:

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

## 5. Проверка systemd timer

Установи скрипт и systemd files:

```bash
sudo cp scripts/user_manager.sh /usr/local/bin/user_manager.sh
sudo chmod +x /usr/local/bin/user_manager.sh
sudo cp systemd/user-cleanup.service /etc/systemd/system/
sudo cp systemd/user-cleanup.timer /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now user-cleanup.timer
```

Проверь timer:

```bash
systemctl list-timers user-cleanup.timer
sudo systemctl status user-cleanup.timer
```

## 6. Что сказать в конце

Короткое завершение:

> В результате видно, что скрипт создает пользователей из CSV, добавляет их в специальную группу managed_users, настраивает домашние директории, SSH-ключи и expiry policy. Cleanup безопасен, потому что удаляет только expired users из managed_users. Systemd timer автоматически запускает cleanup каждую неделю. Все действия логируются в /var/log/user_manager.log.

## 7. Безопасная очистка после демо

Удалить только пользователей проекта:

```bash
for user in $(getent group managed_users | awk -F: '{print $4}' | tr ',' ' '); do
    sudo userdel -r "$user" 2>/dev/null || true
done
```

Отключить timer:

```bash
sudo systemctl disable --now user-cleanup.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/user-cleanup.service /etc/systemd/system/user-cleanup.timer
sudo systemctl daemon-reload
```

Удалить установленный скрипт и лог, если они больше не нужны:

```bash
sudo rm -f /usr/local/bin/user_manager.sh
sudo rm -f /var/log/user_manager.log
```
