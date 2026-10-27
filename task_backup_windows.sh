#!/bin/bash
# Dagligt backup-script för Awaio på Windows/WSL2
# Körs via Windows Task Scheduler eller WSL crontab kl 02:00

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

BACKUP_DIR="./backups"
RETENTION_DAYS=7
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOG_FILE="./logs/backup_$(date +%Y%m%d).log"

mkdir -p "$BACKUP_DIR"
mkdir -p logs

log() {
    echo "$1" >> "$LOG_FILE"
}

echo "========================================" >> "$LOG_FILE"
echo "Backup started: $(date)" >> "$LOG_FILE"
echo "========================================" >> "$LOG_FILE"

# Kontrollera att PostgreSQL-containern körs
if ! docker ps | grep -q awaio-postgres; then
    log "ERROR: PostgreSQL container is not running"
    exit 1
fi

# ============================================
# Backup 1: Metabase application database
# ============================================
log ""
log "-> Backing up Metabase database..."

METABASE_BACKUP="${BACKUP_DIR}/metabase_app_${TIMESTAMP}.sql.gz"

docker compose exec -T postgres \
    pg_dump -U awaio_user metabase_app | gzip > "$METABASE_BACKUP" 2>> "$LOG_FILE"

if [ $? -eq 0 ] && [ -s "$METABASE_BACKUP" ]; then
    METABASE_SIZE=$(du -h "$METABASE_BACKUP" | cut -f1)
    log "OK: Metabase backup: $METABASE_BACKUP ($METABASE_SIZE)"
else
    log "FAIL: Metabase backup FAILED"
    exit 1
fi

# ============================================
# Backup 2: Awaio application database
# ============================================
log ""
log "-> Backing up Awaio database..."

AWAIO_BACKUP="${BACKUP_DIR}/awaio_db_${TIMESTAMP}.sql.gz"

docker compose exec -T postgres \
    pg_dump -U awaio_user awaio_db | gzip > "$AWAIO_BACKUP" 2>> "$LOG_FILE"

if [ $? -eq 0 ] && [ -s "$AWAIO_BACKUP" ]; then
    AWAIO_SIZE=$(du -h "$AWAIO_BACKUP" | cut -f1)
    log "OK: Awaio backup: $AWAIO_BACKUP ($AWAIO_SIZE)"
else
    log "FAIL: Awaio backup FAILED"
    exit 1
fi

# ============================================
# Cleanup: Ta bort gamla backups
# ============================================
log ""
log "-> Cleaning up backups older than ${RETENTION_DAYS} days..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f -mtime +${RETENTION_DAYS} -delete -print | wc -l)
log "Deleted $DELETED_COUNT old backup(s)"

# ============================================
# Sammanfattning
# ============================================
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" | cut -f1)
BACKUP_COUNT=$(find "$BACKUP_DIR" -name "*.sql.gz" -type f | wc -l)

log ""
log "========================================="
log "Backup Summary:"
log "  Metabase backup: $METABASE_SIZE"
log "  Awaio backup:    $AWAIO_SIZE"
log "  Total stored:    $BACKUP_COUNT backups ($TOTAL_SIZE)"
log "========================================="
log "Backup finished: $(date)"
log "========================================="
log ""

# Rensa loggar äldre än 7 dagar
find ./logs -name "backup_*.log" -mtime +7 -delete 2>/dev/null

exit 0
