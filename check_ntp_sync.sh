#!/bin/bash

# --- Переменные ---
MAX_OFFSET="300"                    # Максимально допустимое расхождение времени в секундах (5 минут)
LOG_FILE="/var/log/ntp_fix.log"     # Путь к лог-файлу
DEBUG=0                             # Флаг режима отладки

# --- Обработка аргументов ---
for arg in "$@"; do
    if [[ "$arg" == "--debug" ]]; then
        DEBUG=1
    fi
done

# --- Функции логирования ---
log_info()  { echo "$(date): [INFO] $*"   >> "$LOG_FILE"; }
log_warn()  { echo "$(date): [WARNING] $*" >> "$LOG_FILE"; }
log_error() { echo "$(date): [ERROR] $*"  >> "$LOG_FILE"; }
log_debug() { [[ "$DEBUG" -eq 1 ]] && echo "$(date): [DEBUG] $*" >> "$LOG_FILE"; }


# --------------------------------------------------------------------------------------------------------------------


# --- Проверка существования лог-файла ---
if [ ! -e "$LOG_FILE" ]; then
    touch "$LOG_FILE" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo "$(date): [ERROR] Не удалось создать лог-файл $LOG_FILE. Проверьте права." >&2
        exit 1
    fi
fi

# --- Проверка наличия bc ---
if ! command -v bc &>/dev/null; then
    log_error "Утилита 'bc' не найдена. Установите её для работы скрипта."
    exit 1
fi

# --- Получаем данные о расхождении времени ---
TRACKING_OUTPUT=$(chronyc tracking 2>&1)
if [ $? -ne 0 ]; then
    log_error "Не удалось выполнить 'chronyc tracking': $TRACKING_OUTPUT"
    exit 1
fi

# --- Извлекаем величину расхождения ---
OFFSET=$(echo "$TRACKING_OUTPUT" | grep "System time" | awk '{print $4}' | sed 's/seconds//')
if [ -z "$OFFSET" ]; then
    log_error "Не удалось определить расхождение времени"
    exit 1
fi

# --- Вычисляем абсолютное значение смещения ---
ABS_OFFSET=$(echo "$OFFSET" | awk '{if ($1<0) print -$1; else print $1}')

log_debug "ABS_OFFSET=$ABS_OFFSET, MAX_OFFSET=$MAX_OFFSET"

# --- Проверка расхождения времени ---
if (( $(echo "$ABS_OFFSET > $MAX_OFFSET" | bc -l) )); then
    log_warn "Обнаружено расхождение: $OFFSET сек (порог: $MAX_OFFSET сек)"

    MAKESTEP_OUTPUT=$(chronyc makestep 2>&1)
    MAKESTEP_RESULT=$?
    log_info "Результат chronyc makestep: $MAKESTEP_OUTPUT (код: $MAKESTEP_RESULT)"

    systemctl restart chronyd 2>&1 | tee -a "$LOG_FILE"
    log_info "Служба chronyd перезапущена"
fi
