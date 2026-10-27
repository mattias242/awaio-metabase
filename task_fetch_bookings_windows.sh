#!/bin/bash
# Manuell hämtning av bookings från Awaio API (WSL2/bash).
# Hämtar från (senaste körning - 1 dygn) fram till idag, så 24h buffer täcker sena eller korrigerade bokningar.
# Vid första körningen (ingen state-fil) hämtas senaste 2 dagarna.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

LOG_FILE="./logs/task_scheduler_$(date +%Y%m%d).log"
STATE_FILE="./logs/last_fetch.state"
mkdir -p ./logs

log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log "========================================"
log "Task started: $(date)"
log "========================================"

TODAY=$(date +%Y-%m-%d)

if [ -f "$STATE_FILE" ]; then
    LAST_FETCH=$(tr -d '[:space:]' < "$STATE_FILE")
    if ! date -d "$LAST_FETCH" >/dev/null 2>&1; then
        log "VARNING: kan inte parsa '$LAST_FETCH' i $STATE_FILE — faller tillbaka till 2 dagar sedan"
        LAST_FETCH=$(date -d "$TODAY - 2 days" +%Y-%m-%d)
    fi
else
    log "Ingen tidigare körning — hämtar senaste 2 dagarna"
    LAST_FETCH=$(date -d "$TODAY - 2 days" +%Y-%m-%d)
fi

START_DATE=$(date -d "$LAST_FETCH - 1 day" +%Y-%m-%d)
DAYS=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$START_DATE" +%s) ) / 86400 + 1 ))
[ $DAYS -lt 1 ] && DAYS=1

log "Senaste körning: $LAST_FETCH"
log "Hämtar: --date $START_DATE --days $DAYS"

docker compose --profile tools run --rm fetcher \
    python3 fetch_bookings.py --date "$START_DATE" --days $DAYS --stats >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    printf '%s' "$TODAY" > "$STATE_FILE"
    log "State uppdaterad: last_fetch = $TODAY"
else
    log "Hämtning misslyckades (exit $EXIT_CODE) — state-filen uppdateras inte"
fi

log "========================================"
log "Task finished: $(date)"
log "Exit code: $EXIT_CODE"
log "========================================"
echo "" >> "$LOG_FILE"

exit $EXIT_CODE
