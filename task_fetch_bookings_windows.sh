#!/bin/bash
# Manual fetch of bookings from the Awaio API (WSL2/bash).
# Fetches from (last run - 1 day) up to today, so a 24 h buffer covers late or corrected bookings.
# On the first run (no state file) the last 2 days are fetched.

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
        log "WARNING: cannot parse '$LAST_FETCH' i $STATE_FILE — falling back to 2 days ago"
        LAST_FETCH=$(date -d "$TODAY - 2 days" +%Y-%m-%d)
    fi
else
    log "No previous run — fetching the last 2 days"
    LAST_FETCH=$(date -d "$TODAY - 2 days" +%Y-%m-%d)
fi

START_DATE=$(date -d "$LAST_FETCH - 1 day" +%Y-%m-%d)
DAYS=$(( ( $(date -d "$TODAY" +%s) - $(date -d "$START_DATE" +%s) ) / 86400 + 1 ))
[ $DAYS -lt 1 ] && DAYS=1

log "Last run: $LAST_FETCH"
log "Fetching: --date $START_DATE --days $DAYS"

docker compose --profile tools run --rm fetcher \
    python3 fetch_bookings.py --date "$START_DATE" --days $DAYS --stats >> "$LOG_FILE" 2>&1

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    printf '%s' "$TODAY" > "$STATE_FILE"
    log "State updated: last_fetch = $TODAY"
else
    log "Fetch failed (exit $EXIT_CODE) — state file not updated"
fi

log "========================================"
log "Task finished: $(date)"
log "Exit code: $EXIT_CODE"
log "========================================"
echo "" >> "$LOG_FILE"

exit $EXIT_CODE
