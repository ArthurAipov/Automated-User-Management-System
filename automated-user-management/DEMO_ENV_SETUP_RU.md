# Demo Environment Setup on macOS

Этот файл объясняет, как подготовить среду для демо-видео на Mac. Сам проект нужно запускать не на macOS, а внутри Ubuntu/Debian VM.

## Рекомендуемый вариант: Multipass

Multipass быстро создает Ubuntu VM и удобен для записи демо из терминала.

## 1. Установить Multipass на Mac

Если установлен Homebrew:

```bash
brew install --cask multipass
```

Если Homebrew нет, можно установить Multipass вручную с сайта Canonical.

Проверить установку:

```bash
multipass version
```

## 2. Создать Ubuntu VM

```bash
multipass launch --name user-demo --cpus 2 --memory 2G --disk 10G
```

Проверить, что VM запущена:

```bash
multipass list
```

Зайти внутрь VM:

```bash
multipass shell user-demo
```

## 3. Подготовить Ubuntu внутри VM

Внутри VM выполни:

```bash
sudo apt update
sudo apt install -y openssh-client tree
```

Проверить нужные команды:

```bash
command -v useradd
command -v usermod
command -v userdel
command -v groupadd
command -v chage
command -v ssh-keygen
command -v systemctl
```

## 4. Передать проект с Mac в VM

Выйди из VM, если ты внутри нее:

```bash
exit
```

На Mac перейди в папку, где лежит проект:

```bash
cd /Users/arturaipov/Downloads/Automated-User-Management-System
```

Передай папку проекта в Ubuntu VM:

```bash
multipass transfer -r automated-user-management user-demo:/home/ubuntu/
```

Снова зайди в VM:

```bash
multipass shell user-demo
```

Перейди в проект:

```bash
cd automated-user-management
chmod +x scripts/user_manager.sh
```

## 5. Очистить старое состояние перед записью

Если ты уже запускал демо раньше, лучше очистить старых тестовых пользователей, timer и лог.

```bash
if getent group managed_users >/dev/null; then
    for user in $(getent group managed_users | awk -F: '{print $4}' | tr ',' ' '); do
        sudo userdel -r "$user" 2>/dev/null || true
    done
fi

sudo groupdel managed_users 2>/dev/null || true
sudo groupdel students 2>/dev/null || true
sudo groupdel interns 2>/dev/null || true
sudo groupdel labusers 2>/dev/null || true
sudo groupdel research 2>/dev/null || true

sudo systemctl disable --now user-cleanup.timer 2>/dev/null || true
sudo rm -f /etc/systemd/system/user-cleanup.service /etc/systemd/system/user-cleanup.timer
sudo systemctl daemon-reload

sudo rm -f /usr/local/bin/user_manager.sh
sudo rm -f /var/log/user_manager.log
```

## 6. Проверить, что демо начинается с чистого состояния

```bash
getent group managed_users || echo "managed_users group does not exist yet"
getent passwd student01 || echo "student01 does not exist yet"
sudo test ! -f /var/log/user_manager.log && echo "log file does not exist yet"
```

## 7. Быстрый smoke test перед записью

Проверь help:

```bash
./scripts/user_manager.sh --help
```

Проверь dry-run:

```bash
sudo ./scripts/user_manager.sh --create users.csv --dry-run
```

Если dry-run показывает команды `groupadd`, `useradd`, `install`, `chage`, `ssh-keygen`, среда готова.

## 8. Что открыть перед стартом записи

Перед нажатием Record подготовь:

1. Терминал внутри Ubuntu VM.
2. Папку проекта `~/automated-user-management`.
3. Файл `DEMO_VIDEO_GUIDE_RU.md` рядом, чтобы смотреть сценарий.
4. Увеличенный размер шрифта терминала.

На Mac можно увеличить шрифт терминала:

```text
Command + Plus
```

## 9. Запись экрана на Mac

1. Нажми `Command + Shift + 5`.
2. Выбери запись выбранной области или всего экрана.
3. В `Options` выбери микрофон.
4. Нажми `Record`.
5. Выполняй команды из `DEMO_VIDEO_GUIDE_RU.md`.

## 10. После демо

Если нужно полностью удалить VM:

```bash
multipass stop user-demo
multipass delete user-demo
multipass purge
```

Если VM нужно оставить, но очистить тестовых пользователей, используй команды из раздела 5.

## Альтернатива: UTM или VirtualBox

Можно установить Ubuntu Desktop или Ubuntu Server в UTM/VirtualBox, затем:

```bash
sudo apt update
sudo apt install -y openssh-client tree
```

Дальше перенеси папку `automated-user-management` в VM через shared folder, SCP, GitHub или drag-and-drop, если VM это поддерживает.

После переноса:

```bash
cd automated-user-management
chmod +x scripts/user_manager.sh
sudo ./scripts/user_manager.sh --create users.csv --dry-run
```
