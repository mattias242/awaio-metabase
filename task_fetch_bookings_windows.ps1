#Requires -Version 5.1
# Manual fetch of bookings from the Awaio API.
# Fetches from (last run - 1 day) up to today, so a 24 h buffer covers late or corrected bookings.
# On the first run (no state file) the last 2 days are fetched.

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

$LogDir    = Join-Path $ScriptDir "logs"
$LogFile   = Join-Path $LogDir "task_scheduler_$(Get-Date -Format 'yyyyMMdd').log"
$StateFile = Join-Path $LogDir "last_fetch.state"

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

function Log {
    param([string]$msg)
    Add-Content -Path $LogFile -Value $msg
    Write-Host $msg
}

Log "========================================"
Log "Task started: $(Get-Date)"
Log "========================================"

$today = (Get-Date).Date

if (Test-Path $StateFile) {
    $lastFetchStr = (Get-Content $StateFile -Raw).Trim()
    try {
        $lastFetch = [datetime]::ParseExact($lastFetchStr, 'yyyy-MM-dd', $null)
    } catch {
        Log "WARNING: cannot parse '$lastFetchStr' i $StateFile — falling back to 2 days ago"
        $lastFetch = $today.AddDays(-2)
    }
} else {
    Log "No previous run — fetching the last 2 days"
    $lastFetch = $today.AddDays(-2)
}

$startDate    = $lastFetch.AddDays(-1)
$startDateStr = $startDate.ToString('yyyy-MM-dd')
$days         = [math]::Max(1, [int]($today - $startDate).TotalDays + 1)

Log "Last run: $($lastFetch.ToString('yyyy-MM-dd'))"
Log "Fetching: --date $startDateStr --days $days"

$output = docker compose --profile tools run --rm fetcher `
    python3 fetch_bookings.py --date $startDateStr --days $days --stats 2>&1
$exitCode = $LASTEXITCODE

$output | ForEach-Object { Log $_ }

if ($exitCode -eq 0) {
    $today.ToString('yyyy-MM-dd') | Out-File -FilePath $StateFile -Encoding ASCII -NoNewline
    Log "State updated: last_fetch = $($today.ToString('yyyy-MM-dd'))"
} else {
    Log "Fetch failed (exit $exitCode) — state file not updated"
}

Log "========================================"
Log "Task finished: $(Get-Date)"
Log "Exit code: $exitCode"
Log "========================================"
Log ""

exit $exitCode
