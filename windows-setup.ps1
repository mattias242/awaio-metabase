#Requires -Version 5.1
<#
.SYNOPSIS
    Awaio Windows 11 Deployment Setup Script

.DESCRIPTION
    Sätter upp Awaio på Windows 11 med Docker Desktop.
    Kräver inte WSL2 — allt körs direkt i PowerShell.

.NOTES
    Kör i PowerShell som administratör för att kunna registrera
    schemalagda uppgifter i Windows Task Scheduler.

    Användning:
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
        .\windows-setup.ps1
#>

[CmdletBinding()]
param()

# ============================================
# Hjälpfunktioner
# ============================================
function Write-Header {
    param([string]$Text)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Blue
    Write-Host "  $Text" -ForegroundColor Blue
    Write-Host "========================================" -ForegroundColor Blue
}
function Write-OK      { param([string]$Text) Write-Host "OK  $Text" -ForegroundColor Green }
function Write-Warn    { param([string]$Text) Write-Host "!   $Text" -ForegroundColor Yellow }
function Write-Err     { param([string]$Text) Write-Host "ERR $Text" -ForegroundColor Red }
function Write-Info    { param([string]$Text) Write-Host "... $Text" -ForegroundColor Cyan }

function Read-YesNo {
    param([string]$Prompt, [bool]$DefaultYes = $true)
    $hint = if ($DefaultYes) { "Y/n" } else { "y/N" }
    $answer = Read-Host "$Prompt ($hint)"
    if ([string]::IsNullOrWhiteSpace($answer)) { return $DefaultYes }
    return $answer -match '^[Yy]'
}

# ============================================
# Byt till script-katalogen
# ============================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Clear-Host
Write-Header "Awaio Windows 11 Deployment Setup"
Write-Host ""
Write-Host "  Sätter upp Awaio på Windows 11 med Docker Desktop."
Write-Host ""

if (-not (Test-Path "docker-compose.yml")) {
    Write-Err "Kan inte hitta docker-compose.yml"
    Write-Err "Kör scriptet från Awaio-projektmappen!"
    exit 1
}

# ============================================
# Steg 1: Kontrollera förutsättningar
# ============================================
Write-Header "Steg 1: Kontrollera förutsättningar"

# Docker CLI
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker är inte installerat eller inte i PATH"
    Write-Warn "Hämta Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
}
Write-OK "Docker: $(docker --version)"

# Docker Compose v2
$composeTest = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker Compose v2 saknas ('docker compose' fungerar inte)"
    Write-Warn "Uppgradera Docker Desktop till version 3.4.0+"
    exit 1
}
Write-OK "Compose: $composeTest"

# Docker daemon
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker Desktop verkar inte köra"
    Write-Warn "Starta Docker Desktop och försök igen"
    exit 1
}
Write-OK "Docker Desktop körs"

# RAM-kontroll
$os = Get-CimInstance Win32_OperatingSystem
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeMB  = [math]::Round($os.FreePhysicalMemory / 1024)
Write-Info "RAM: $totalMB MB totalt, $freeMB MB ledigt"
if ($freeMB -lt 2000) {
    Write-Warn "Mindre än 2 GB ledigt — rekommenderar minimal profil"
}

# Port-kontroll
Write-Info "Kontrollerar portar..."
foreach ($port in @(5433, 3000)) {
    $inUse = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($inUse) {
        Write-Warn "Port $port verkar redan vara upptagen"
    } else {
        Write-OK "Port $port är ledig"
    }
}

# Admin-check (behövs för Task Scheduler)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "Körs INTE som administratör — Task Scheduler-registrering kräver admin"
}

# ============================================
# Steg 2: Konfigurera .env
# ============================================
Write-Header "Steg 2: Konfigurera miljövariabler"

if (Test-Path ".env") {
    Write-Warn ".env finns redan"
    if (Read-YesNo "Skriv över med .env.example?" $false) {
        Copy-Item ".env.example" ".env" -Force
        Write-OK ".env kopierad från .env.example"
    } else {
        Write-Info "Behåller befintlig .env"
    }
} else {
    Copy-Item ".env.example" ".env"
    Write-OK ".env skapad från .env.example"
    Write-Warn "Uppdatera .env med dina Awaio API-credentials (AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET)"
}

# ============================================
# Steg 3: Välj deployment-profil
# ============================================
Write-Header "Steg 3: Välj deployment-profil"

Write-Host ""
Write-Host "  Välj vilken profil du vill använda:"
Write-Host ""
Write-Host "  1) Minimal  (PostgreSQL + Metabase)       ~3 GB RAM"
Write-Host "  2) Admin    (+ pgAdmin)                   ~3.5 GB RAM"
Write-Host "  3) AI       (+ MindsDB + Chat)            ~5 GB RAM"
Write-Host "  4) Full     (alla tjänster)               ~6 GB RAM"
Write-Host ""
$profileChoice = Read-Host "Välj profil (1-4) [default: 1]"

switch ($profileChoice) {
    "2" { $composeProfile = "--profile admin"; $profileName = "Admin" }
    "3" { $composeProfile = "--profile ai";    $profileName = "AI" }
    "4" { $composeProfile = "--profile full";  $profileName = "Full" }
    default { $composeProfile = "";            $profileName = "Minimal" }
}

Write-OK "Profil: $profileName"

# ============================================
# Steg 4: Skapa kataloger
# ============================================
Write-Header "Steg 4: Skapa kataloger"

New-Item -ItemType Directory -Force -Path "backups" | Out-Null
New-Item -ItemType Directory -Force -Path "logs"    | Out-Null
Write-OK "Kataloger skapade (backups, logs)"

# ============================================
# Steg 5: Pull och starta containers
# ============================================
Write-Header "Steg 5: Starta containers"

Write-Host ""
if (Read-YesNo "Starta containers nu?" $true) {
    Write-Info "Hämtar Docker images (kan ta några minuter)..."
    Invoke-Expression "docker compose $composeProfile pull"

    Write-Info "Startar containers..."
    Invoke-Expression "docker compose $composeProfile up -d"

    Write-Host ""
    Write-OK "Containers startade!"
    Write-Info "Container-status:"
    docker compose ps
} else {
    Write-Info "Starta manuellt med:"
    Write-Host "  docker compose $composeProfile up -d"
}

# ============================================
# Steg 6: Metabase-restore
# ============================================
Write-Header "Steg 6: Återställ Metabase-konfiguration"

$metabaseBackup = Join-Path $ScriptDir "metabase\metabase_app_backup.sql.gz"

if (Test-Path $metabaseBackup) {
    $backupSize = [math]::Round((Get-Item $metabaseBackup).Length / 1MB, 1)
    Write-Host ""
    Write-Host "  Hittade Metabase-backup ($backupSize MB)"
    Write-Host "  Återställning ger dig befintliga frågor och dashboards från NAS."
    Write-Host ""

    if (Read-YesNo "Återställ Metabase-konfiguration?" $true) {
        Write-Info "Väntar på att PostgreSQL ska bli redo..."
        $retries = 0
        do {
            Start-Sleep -Seconds 10
            $ready = docker compose exec -T postgres pg_isready -U awaio_user 2>&1
            $retries++
            if ($retries -gt 30) {
                Write-Err "PostgreSQL svarar inte — avbryter restore"
                break
            }
        } until ($ready -match "accepting connections")

        Write-Info "Skapar metabase_app-databasen om den inte finns..."
        docker compose exec -T postgres `
            psql -U awaio_user -c "CREATE DATABASE metabase_app OWNER awaio_user;" 2>$null

        Write-Info "Dekomprimerar och återställer backup..."
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $fs     = [System.IO.File]::OpenRead($metabaseBackup)
            $gz     = [System.IO.Compression.GZipStream]::new($fs, [System.IO.Compression.CompressionMode]::Decompress)
            $reader = [System.IO.StreamReader]::new($gz, [System.Text.Encoding]::UTF8)
            $sql    = $reader.ReadToEnd()
            $reader.Dispose(); $gz.Dispose(); $fs.Dispose()

            $sql | docker exec -i awaio-postgres psql -U awaio_user -d metabase_app

            if ($LASTEXITCODE -eq 0) {
                Write-OK "Metabase-konfiguration återställd!"
                Write-Info "Starta om Metabase för att ladda konfigurationen:"
                Write-Host "  docker compose restart metabase"
            } else {
                Write-Err "Restore misslyckades (exit $LASTEXITCODE)"
            }
        } catch {
            Write-Err "Fel vid restore: $_"
        }
    } else {
        Write-Info "Hoppar över Metabase-restore"
    }
} else {
    Write-Warn "Ingen Metabase-backup hittad (metabase\metabase_app_backup.sql.gz)"
    Write-Info "Lägg en existerande Metabase-dump i metabase\ för att återställa tidigare dashboards."
}

# ============================================
# Steg 7: Schemalägg daglig backup
# ============================================
Write-Header "Steg 7: Schemalägg daglig backup"

Write-Host ""
Write-Host "  Vill du registrera daglig backup (kl 02:00) i Windows Task Scheduler?"
Write-Host "  Datahämtning (fetch_bookings) körs manuellt — inte schemalagt."
Write-Host ""

if (-not $isAdmin) {
    Write-Warn "Kräver administratörsbehörighet — hoppar över automatisk registrering"
    Write-Info "Kör scriptet som administratör för att aktivera schemaläggning"
} elseif (Read-YesNo "Registrera 'Awaio - Daily Backup'?" $false) {
    $backupScript = Join-Path $ScriptDir "task_backup_windows.ps1"

    $backupAction   = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$backupScript`""
    $backupTrigger  = New-ScheduledTaskTrigger -Daily -At "02:00"
    $backupSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([timespan]::FromMinutes(60)) `
        -StartWhenAvailable
    Register-ScheduledTask -TaskName "Awaio - Daily Backup" `
        -Action $backupAction -Trigger $backupTrigger -Settings $backupSettings `
        -RunLevel Highest -Force | Out-Null
    Write-OK "Task Scheduler: 'Awaio - Daily Backup' (dagligen kl 02:00)"
} else {
    Write-Info "Kör manuellt vid behov:"
    Write-Host "  .\task_backup_windows.ps1"
}

Write-Host ""
Write-Info "Hämta bookings manuellt (räknar ut datumintervall från senaste körning):"
Write-Host "  .\task_fetch_bookings_windows.ps1"

# ============================================
# Klar!
# ============================================
Write-Host ""
Write-Header "Installation klar!"
Write-Host ""
Write-Info "Access-URLer:"
Write-Host "  Metabase:   http://localhost:3000"
if ($composeProfile -match "admin|full") {
    Write-Host "  pgAdmin:    http://localhost:5050"
}
if ($composeProfile -match "ai|full") {
    Write-Host "  MindsDB:    http://localhost:47334"
    Write-Host "  Chat App:   http://localhost:8501"
}
Write-Host "  PostgreSQL: localhost:5433"
Write-Host ""
Write-Info "Hämta data manuellt:"
Write-Host "  docker compose --profile tools run --rm fetcher python3 fetch_entities.py --stats"
Write-Host "  docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --date 2025-01-01 --days 30 --stats"
Write-Host ""
Write-Info "Observera: Docker Desktop måste köra för att containers ska starta."
Write-Host "           Aktivera 'Start Docker Desktop when you log in' i inställningarna."
Write-Host ""
Write-OK "Tack för att du använder Awaio!"
Write-Host ""
