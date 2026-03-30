# run-cleanup.ps1 — one-liner entry point for SmartConsoleCleanup
# Usage: irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/run-cleanup.ps1 | iex

$ErrorActionPreference = 'Stop'

# ── Self-elevate if not already running as Administrator ──────────────────────
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
           ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "Not running as Administrator — relaunching elevated..." -ForegroundColor Yellow
    $psExe = (Get-Process -Id $PID).MainModule.FileName
    # Re-run this same one-liner in an elevated session
    $cmd = 'irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/run-cleanup.ps1 | iex'
    Start-Process $psExe -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"$cmd`"" -Verb RunAs -Wait
    exit
}

# ── Already elevated — download and run ──────────────────────────────────────
$url = "https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/cleanup.ps1"

Write-Host "Downloading SmartConsole Cleanup script..." -ForegroundColor Cyan

try {
    $script = Invoke-RestMethod -Uri $url -UseBasicParsing
} catch {
    Write-Error "Failed to download script: $($_.Exception.Message)"
    exit 1
}

Write-Host "Running cleanup (NukeAll mode)..." -ForegroundColor Yellow

& ([scriptblock]::Create($script)) -NukeAll -NukeOnly
