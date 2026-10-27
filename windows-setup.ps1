#Requires -Version 5.1
<#
.SYNOPSIS
    Awaio Windows 11 Deployment Setup Script

.DESCRIPTION
    Sets up Awaio on Windows 11 with Docker Desktop.
    Does not need WSL2 — everything runs directly in PowerShell.

.NOTES
    Run in PowerShell as administrator to be able to register
    scheduled tasks in Windows Task Scheduler.

    Usage:
        Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
        .\windows-setup.ps1
#>

[CmdletBinding()]
param()

# ============================================
# Helper functions
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
# Change to the script directory
# ============================================
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Clear-Host
Write-Header "Awaio Windows 11 Deployment Setup"
Write-Host ""
Write-Host "  Sets up Awaio on Windows 11 with Docker Desktop."
Write-Host ""

if (-not (Test-Path "docker-compose.yml")) {
    Write-Err "Cannot find docker-compose.yml"
    Write-Err "Run the script from the Awaio project folder!"
    exit 1
}

# ============================================
# Step 1: Check prerequisites
# ============================================
Write-Header "Step 1: Check prerequisites"

# Docker CLI
if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-Err "Docker is not installed or not in PATH"
    Write-Warn "Get Docker Desktop: https://www.docker.com/products/docker-desktop/"
    exit 1
}
Write-OK "Docker: $(docker --version)"

# Docker Compose v2
$composeTest = docker compose version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker Compose v2 is missing ('docker compose' does not work)"
    Write-Warn "Upgrade Docker Desktop to version 3.4.0+"
    exit 1
}
Write-OK "Compose: $composeTest"

# Docker daemon
$dockerInfo = docker info 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "Docker Desktop does not seem to be running"
    Write-Warn "Start Docker Desktop and try again"
    exit 1
}
Write-OK "Docker Desktop is running"

# RAM check
$os = Get-CimInstance Win32_OperatingSystem
$totalMB = [math]::Round($os.TotalVisibleMemorySize / 1024)
$freeMB  = [math]::Round($os.FreePhysicalMemory / 1024)
Write-Info "RAM: $totalMB MB total, $freeMB MB free"
if ($freeMB -lt 2000) {
    Write-Warn "Less than 2 GB free — the minimal profile is recommended"
}

# Port check
Write-Info "Checking ports..."
foreach ($port in @(5433, 3000)) {
    $inUse = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if ($inUse) {
        Write-Warn "Port $port seems to be in use already"
    } else {
        Write-OK "Port $port is free"
    }
}

# Admin check (needed for Task Scheduler)
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warn "NOT running as administrator — Task Scheduler registration requires admin"
}

# ============================================
# Step 2: Configure .env
# ============================================
Write-Header "Step 2: Configure environment variables"

if (Test-Path ".env") {
    Write-Warn ".env already exists"
    if (Read-YesNo "Overwrite with .env.example?" $false) {
        Copy-Item ".env.example" ".env" -Force
        Write-OK ".env copied from .env.example"
    } else {
        Write-Info "Keeping the existing .env"
    }
} else {
    Copy-Item ".env.example" ".env"
    Write-OK ".env created from .env.example"
    Write-Warn "Update .env with your Awaio API credentials (AWAIO_CLIENT_ID / AWAIO_CLIENT_SECRET)"
}

# ============================================
# Step 3: Choose a deployment profile
# ============================================
Write-Header "Step 3: Choose a deployment profile"

Write-Host ""
Write-Host "  Choose which profile to use:"
Write-Host ""
Write-Host "  1) Minimal  (PostgreSQL + Metabase)       ~3 GB RAM"
Write-Host "  2) Admin    (+ pgAdmin)                   ~3.5 GB RAM"
Write-Host "  3) AI       (+ MindsDB + Chat)            ~5 GB RAM"
Write-Host "  4) Full     (all services)               ~6 GB RAM"
Write-Host ""
$profileChoice = Read-Host "Choose profile (1-4) [default: 1]"

switch ($profileChoice) {
    "2" { $composeProfile = "--profile admin"; $profileName = "Admin" }
    "3" { $composeProfile = "--profile ai";    $profileName = "AI" }
    "4" { $composeProfile = "--profile full";  $profileName = "Full" }
    default { $composeProfile = "";            $profileName = "Minimal" }
}

Write-OK "Profile: $profileName"

# ============================================
# Step 4: Create directories
# ============================================
Write-Header "Step 4: Create directories"

New-Item -ItemType Directory -Force -Path "backups" | Out-Null
New-Item -ItemType Directory -Force -Path "logs"    | Out-Null
Write-OK "Directories created (backups, logs)"

# ============================================
# Step 5: Pull and start containers
# ============================================
Write-Header "Step 5: Start containers"

Write-Host ""
if (Read-YesNo "Start containers now?" $true) {
    Write-Info "Pulling Docker images (may take a few minutes)..."
    Invoke-Expression "docker compose $composeProfile pull"

    Write-Info "Starting containers..."
    Invoke-Expression "docker compose $composeProfile up -d"

    Write-Host ""
    Write-OK "Containers started!"
    Write-Info "Container-status:"
    docker compose ps
} else {
    Write-Info "Start manually with:"
    Write-Host "  docker compose $composeProfile up -d"
}

# ============================================
# Step 6: Metabase restore
# ============================================
Write-Header "Step 6: Restore the Metabase configuration"

$metabaseBackup = Join-Path $ScriptDir "metabase\metabase_app_backup.sql.gz"

if (Test-Path $metabaseBackup) {
    $backupSize = [math]::Round((Get-Item $metabaseBackup).Length / 1MB, 1)
    Write-Host ""
    Write-Host "  Found a Metabase backup ($backupSize MB)"
    Write-Host "  Restoring gives you the existing questions and dashboards."
    Write-Host ""

    if (Read-YesNo "Restore the Metabase configuration?" $true) {
        Write-Info "Waiting for PostgreSQL to become ready..."
        $retries = 0
        do {
            Start-Sleep -Seconds 10
            $ready = docker compose exec -T postgres pg_isready -U awaio_user 2>&1
            $retries++
            if ($retries -gt 30) {
                Write-Err "PostgreSQL is not responding — aborting restore"
                break
            }
        } until ($ready -match "accepting connections")

        Write-Info "Creating the metabase_app database if it does not exist..."
        docker compose exec -T postgres `
            psql -U awaio_user -c "CREATE DATABASE metabase_app OWNER awaio_user;" 2>$null

        Write-Info "Decompressing and restoring the backup..."
        try {
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            $fs     = [System.IO.File]::OpenRead($metabaseBackup)
            $gz     = [System.IO.Compression.GZipStream]::new($fs, [System.IO.Compression.CompressionMode]::Decompress)
            $reader = [System.IO.StreamReader]::new($gz, [System.Text.Encoding]::UTF8)
            $sql    = $reader.ReadToEnd()
            $reader.Dispose(); $gz.Dispose(); $fs.Dispose()

            $sql | docker exec -i awaio-postgres psql -U awaio_user -d metabase_app

            if ($LASTEXITCODE -eq 0) {
                Write-OK "Metabase configuration restored!"
                Write-Info "Restart Metabase to load the configuration:"
                Write-Host "  docker compose restart metabase"
            } else {
                Write-Err "Restore failed (exit $LASTEXITCODE)"
            }
        } catch {
            Write-Err "Error during restore: $_"
        }
    } else {
        Write-Info "Skipping the Metabase restore"
    }
} else {
    Write-Warn "No Metabase backup found (metabase\metabase_app_backup.sql.gz)"
    Write-Info "Put an existing Metabase dump in metabase\ to restore earlier dashboards."
}

# ============================================
# Step 7: Schedule a daily backup
# ============================================
Write-Header "Step 7: Schedule a daily backup"

Write-Host ""
Write-Host "  Do you want to register a daily backup (at 02:00) in Windows Task Scheduler?"
Write-Host "  Data fetching (fetch_bookings) is run by the scheduler container, not here."
Write-Host ""

if (-not $isAdmin) {
    Write-Warn "Requires administrator rights — skipping automatic registration"
    Write-Info "Run the script as administrator to enable scheduling"
} elseif (Read-YesNo "Register 'Awaio - Daily Backup'?" $false) {
    $backupScript = Join-Path $ScriptDir "task_backup_windows.ps1"

    $backupAction   = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -ExecutionPolicy Bypass -File `"$backupScript`""
    $backupTrigger  = New-ScheduledTaskTrigger -Daily -At "02:00"
    $backupSettings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit ([timespan]::FromMinutes(60)) `
        -StartWhenAvailable
    Register-ScheduledTask -TaskName "Awaio - Daily Backup" `
        -Action $backupAction -Trigger $backupTrigger -Settings $backupSettings `
        -RunLevel Highest -Force | Out-Null
    Write-OK "Task Scheduler: 'Awaio - Daily Backup' (daily at 02:00)"
} else {
    Write-Info "Run manually when needed:"
    Write-Host "  .\task_backup_windows.ps1"
}

Write-Host ""
Write-Info "Fetch bookings manually (works out the date range from the last run):"
Write-Host "  .\task_fetch_bookings_windows.ps1"

# ============================================
# Done!
# ============================================
Write-Host ""
Write-Header "Installation complete!"
Write-Host ""
Write-Info "Access URLs:"
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
Write-Info "Fetch data manually:"
Write-Host "  docker compose --profile tools run --rm fetcher python3 fetch_entities.py --stats"
Write-Host "  docker compose --profile tools run --rm fetcher python3 fetch_bookings.py --date 2025-01-01 --days 30 --stats"
Write-Host ""
Write-Info "Note: Docker Desktop must be running for the containers to start."
Write-Host "      Enable 'Start Docker Desktop when you log in' in the settings."
Write-Host ""
Write-OK "Thanks for using Awaio!"
Write-Host ""
