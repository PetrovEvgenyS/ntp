#!/bin/bash

MAX_OFFSET="300"                    # Максимально допустимое расхождение времени в секундах (5 минут)
LOG_FILE="/var/log/ntp_fix.log"     # Лог файл


# --------------------------------------------------------------------------------------------------------------------


# Получаем данные о расхождении времени
TRACKING_OUTPUT=$(chronyc tracking 2>&1)
if [ $? -ne 0 ]; then
    echo "$(date): [ERROR] Не удалось выполнить chronyc tracking: $TRACKING_OUTPUT" >> "$LOG_FILE"
    exit 1
fi

# Извлекаем величину расхождения
OFFSET=$(echo "$TRACKING_OUTPUT" | grep "System time" | awk '{print $4}' | sed 's/seconds//')
if [ -z "$OFFSET" ]; then
    echo "$(date): [ERROR] Не удалось определить расхождение времени" >> "$LOG_FILE"
    exit 1
fi

# "Функция ABS", которая принимает число (целое, с плавающей точкой или комплексное) и возвращает его абсолютное значение.
ABS_OFFSET=$(echo $OFFSET | awk '{if ($1<0) print -$1; else print $1}')

# DEBUG
echo "$(date): DEBUG: ABS_OFFSET=$ABS_OFFSET, MAX_OFFSET=$MAX_OFFSET" >> "$LOG_FILE"

# Проверка расхождения времени
if (( $(echo "$ABS_OFFSET > $MAX_OFFSET" | bc -l) )); then
    echo "$(date): [WARNING] Обнаружено расхождение: $OFFSET сек (порог: $MAX_OFFSET сек)" >> "$LOG_FILE"
    
    # Выполняем синхронизацию и логируем результат
    MAKESTEP_OUTPUT=$(chronyc makestep 2>&1)
    MAKESTEP_RESULT=$?
    echo "$(date): Результат chronyc makestep: $MAKESTEP_OUTPUT (код: $MAKESTEP_RESULT)" >> "$LOG_FILE"
      
    # Перезапускаем chronyd для надежности
    systemctl restart chronyd 2>&1 | tee -a "$LOG_FILE"
    echo "$(date): Служба chronyd перезапущена" >> "$LOG_FILE"
fi
