#Requires -Version 5.1
# Dagligt backup-script för Awaio på Windows
# Registreras i Windows Task Scheduler av windows-setup.ps1

$ScriptDir    = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$BackupDir     = Join-Path $ScriptDir "backups"
$RetentionDays = 7
$Timestamp     = Get-Date -Format "yyyyMMdd_HHmmss"
$LogDir        = Join-Path $ScriptDir "logs"
$LogFile       = Join-Path $LogDir "backup_$(Get-Date -Format 'yyyyMMdd').log"

New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir    | Out-Null

function Log { param([string]$msg) Add-Content -Path $LogFile -Value $msg }

Log "========================================"
Log "Backup started: $(Get-Date)"
Log "========================================"

# Kontrollera att PostgreSQL-containern körs
$running = docker ps --filter "name=awaio-postgres" --format "{{.Names}}" 2>&1
if ($running -notmatch "awaio-postgres") {
    Log "ERROR: PostgreSQL container is not running"
    exit 1
}

# ============================================
# Backup 1: Metabase application database
# ============================================
Log ""
Log "-> Backing up Metabase database..."

$metabaseBackup = Join-Path $BackupDir "metabase_app_$Timestamp.sql.gz"

docker compose exec -T postgres `
    pg_dump -U awaio_user metabase_app | & {
        # Komprimer via .NET GZipStream
        $fsOut  = [System.IO.File]::Create($metabaseBackup)
        $gz     = [System.IO.Compression.GZipStream]::new($fsOut, [System.IO.Compression.CompressionMode]::Compress)
        $writer = [System.IO.StreamWriter]::new($gz)
        $input | ForEach-Object { $writer.WriteLine($_) }
        $writer.Dispose(); $gz.Dispose(); $fsOut.Dispose()
    }

if ($LASTEXITCODE -eq 0 -and (Test-Path $metabaseBackup) -and (Get-Item $metabaseBackup).Length -gt 0) {
    $metabaseSize = [math]::Round((Get-Item $metabaseBackup).Length / 1KB, 0)
    Log "OK: Metabase backup: $metabaseBackup (${metabaseSize} KB)"
} else {
    Log "FAIL: Metabase backup FAILED"
    exit 1
}

# ============================================
# Backup 2: Awaio application database
# ============================================
Log ""
Log "-> Backing up Awaio database..."

$awaioBackup = Join-Path $BackupDir "awaio_db_$Timestamp.sql.gz"

docker compose exec -T postgres `
    pg_dump -U awaio_user awaio_db | & {
        $fsOut  = [System.IO.File]::Create($awaioBackup)
        $gz     = [System.IO.Compression.GZipStream]::new($fsOut, [System.IO.Compression.CompressionMode]::Compress)
        $writer = [System.IO.StreamWriter]::new($gz)
        $input | ForEach-Object { $writer.WriteLine($_) }
        $writer.Dispose(); $gz.Dispose(); $fsOut.Dispose()
    }

if ($LASTEXITCODE -eq 0 -and (Test-Path $awaioBackup) -and (Get-Item $awaioBackup).Length -gt 0) {
    $awaioSize = [math]::Round((Get-Item $awaioBackup).Length / 1KB, 0)
    Log "OK: Awaio backup: $awaioBackup (${awaioSize} KB)"
} else {
    Log "FAIL: Awaio backup FAILED"
    exit 1
}

# ============================================
# Cleanup: Ta bort gamla backups
# ============================================
Log ""
Log "-> Cleaning up backups older than $RetentionDays days..."
$cutoff = (Get-Date).AddDays(-$RetentionDays)
$deleted = Get-ChildItem -Path $BackupDir -Filter "*.sql.gz" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    ForEach-Object { Remove-Item $_.FullName -Force; $_ }
Log "Deleted $($deleted.Count) old backup(s)"

# ============================================
# Sammanfattning
# ============================================
$backupCount = (Get-ChildItem -Path $BackupDir -Filter "*.sql.gz").Count
$totalSizeKB = [math]::Round(
    (Get-ChildItem -Path $BackupDir -Filter "*.sql.gz" | Measure-Object Length -Sum).Sum / 1KB, 0)

Log ""
Log "========================================="
Log "Backup Summary:"
Log "  Metabase backup: ${metabaseSize} KB"
Log "  Awaio backup:    ${awaioSize} KB"
Log "  Total stored:    $backupCount backups ($totalSizeKB KB)"
Log "========================================="
Log "Backup finished: $(Get-Date)"
Log "========================================="
Log ""

# Rensa loggar äldre än 7 dagar
Get-ChildItem -Path $LogDir -Filter "backup_*.log" |
    Where-Object { $_.LastWriteTime -lt $cutoff } |
    Remove-Item -Force

exit 0
