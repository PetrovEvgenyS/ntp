# setup_ntp.sh

Скрипт автоматической настройки NTP-сервера с помощью chrony для AlmaLinux, Debian и Ubuntu.

## Возможности

- Установка chrony
- Настройка временной зоны (Europe/Moscow)
- Конфигурирование серверов NTP (ru.pool.ntp.org)
- Открытие порта 123/UDP в firewall (firewalld или ufw)
- Настройка локали времени для Debian/Ubuntu
- Проверка статуса синхронизации

## Использование

Запустите скрипт с помощью `sudo`:

```bash
sudo ./setup_ntp.sh
```
