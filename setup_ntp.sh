#!/bin/bash

### ЦВЕТА ##
ESC=$(printf '\033') RESET="${ESC}[0m" MAGENTA="${ESC}[35m" RED="${ESC}[31m" GREEN="${ESC}[32m"

### Функции цветного вывода ##
magentaprint() { echo; printf "${MAGENTA}%s${RESET}\n" "$1"; }
errorprint() { echo; printf "${RED}%s${RESET}\n" "$1"; }
greenprint() { echo; printf "${GREEN}%s${RESET}\n" "$1"; }


# -----------------------------------------------------------------------------------------


# Проверка запуска через sudo
if [ -z "$SUDO_USER" ]; then
    errorprint "Пожалуйста, запустите скрипт через sudo."
    exit 1
fi

# Определение дистрибутива
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
else
    magentaprint "Не удалось определить дистрибутив."
    exit 1
fi

# Функция настройки для AlmaLinux
setup_almalinux() {
    magentaprint "Установка chrony..."
    dnf install -y chrony

    magentaprint "Включение и запуск chronyd..."
    systemctl enable --now chronyd

    magentaprint "Установка временной зоны на Europe/Moscow..."
    timedatectl set-timezone Europe/Moscow

    magentaprint "Настройка серверов NTP..."
    cat > /etc/chrony.conf <<EOL
server 0.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 1.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 2.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 3.ru.pool.ntp.org iburst minpoll 3 maxpoll 8

# Разрешение доступа для локальной сети (при необходимости настроить)
allow 10.100.10.0/24

# Пути для хранения дрейфа и статистики
driftfile /var/lib/chrony/drift

# Корректировка времени, если разница времени превышает 300 секунд (5 минут), с возможностью выполнения до 10 (раз) шагов
makestep 300 10

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony.keys

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Specify directory for log files.
logdir /var/log/chrony
EOL

    magentaprint "Перезапуск chronyd для применения настроек..."
    systemctl restart chronyd

    magentaprint "Открытие порта 123/UDP в firewalld..."
    firewall-cmd --permanent --add-port=123/udp
    firewall-cmd --reload

    magentaprint "Проверка статуса синхронизации времени:"
    chronyc tracking
}

# Функция настройки для Debian/Ubuntu
setup_debian_ubuntu() {
    magentaprint "Установка chrony (современная альтернатива ntp)..."
    apt install -y chrony

    magentaprint "Включение и запуск chronyd..."
    systemctl enable --now chrony
    
    magentaprint "Установка временной зоны на Europe/Moscow..."
    timedatectl set-timezone Europe/Moscow

    magentaprint "Настройка серверов NTP..."
    cat > /etc/chrony/chrony.conf <<EOL
server 0.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 1.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 2.ru.pool.ntp.org iburst minpoll 3 maxpoll 8
server 3.ru.pool.ntp.org iburst minpoll 3 maxpoll 8

# Разрешение доступа для локальной сети (при необходимости настроить)
allow 10.100.10.0/24

# Пути для хранения дрейфа и статистики
driftfile /var/lib/chrony/drift

# Корректировка времени, если разница времени превышает 300 секунд (5 минут), с возможностью выполнения до 10 (раз) шагов
makestep 300 10

# Specify file containing keys for NTP authentication.
keyfile /etc/chrony/chrony.keys

# Save NTS keys and cookies.
ntsdumpdir /var/lib/chrony

# Specify directory for log files.
logdir /var/log/chrony
EOL

    magentaprint "Перезапуск chronyd для применения настроек..."
    systemctl restart chrony

    # Настройка брандмауэра (ufw используется в Debian/Ubuntu)
    magentaprint "Открытие порта 123/UDP в ufw..."
    ufw allow 123/udp
    ufw reload

    magentaprint "Установка локали для корректного отображения времени в 24-часовом формате..."
    localectl set-locale LC_TIME=ru_RU.UTF-8

    magentaprint "Проверка статуса синхронизации времени:"
    chronyc tracking
}


# Выбор действий в зависимости от ОС
case "$OS" in
    "almalinux")
        setup_almalinux
        ;;
    "debian" | "ubuntu")
        setup_debian_ubuntu
        ;;
    *)
        magentaprint "Неподдерживаемый дистрибутив: $OS"
        exit 1
        ;;
esac

# Проверка времени
echo; date; echo

greenprint "Настройка NTP завершена успешно!"
