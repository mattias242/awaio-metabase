#Requires -Version 5.1
# Manuell hämtning av bookings från Awaio API.
# Hämtar från (senaste körning - 1 dygn) fram till idag, så 24h buffer täcker sena eller korrigerade bokningar.
# Vid första körningen (ingen state-fil) hämtas senaste 2 dagarna.

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
        Log "VARNING: kan inte parsa '$lastFetchStr' i $StateFile — faller tillbaka till 2 dagar sedan"
        $lastFetch = $today.AddDays(-2)
    }
} else {
    Log "Ingen tidigare körning — hämtar senaste 2 dagarna"
    $lastFetch = $today.AddDays(-2)
}

$startDate    = $lastFetch.AddDays(-1)
$startDateStr = $startDate.ToString('yyyy-MM-dd')
$days         = [math]::Max(1, [int]($today - $startDate).TotalDays + 1)

Log "Senaste körning: $($lastFetch.ToString('yyyy-MM-dd'))"
Log "Hämtar: --date $startDateStr --days $days"

$output = docker compose --profile tools run --rm fetcher `
    python3 fetch_bookings.py --date $startDateStr --days $days --stats 2>&1
$exitCode = $LASTEXITCODE

$output | ForEach-Object { Log $_ }

if ($exitCode -eq 0) {
    $today.ToString('yyyy-MM-dd') | Out-File -FilePath $StateFile -Encoding ASCII -NoNewline
    Log "State uppdaterad: last_fetch = $($today.ToString('yyyy-MM-dd'))"
} else {
    Log "Hämtning misslyckades (exit $exitCode) — state-filen uppdateras inte"
}

Log "========================================"
Log "Task finished: $(Get-Date)"
Log "Exit code: $exitCode"
Log "========================================"
Log ""

exit $exitCode
