# run-cleanup.ps1 — one-liner entry point for SmartConsoleCleanup
# Usage: irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/run-cleanup.ps1 | iex
#
# To pass parameters, download and dot-source instead:
#   $s = irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/cleanup.ps1
#   & ([scriptblock]::Create($s)) -NukeAll
#   & ([scriptblock]::Create($s)) -NukeAll -DryRun

$ErrorActionPreference = 'Stop'

$url = "https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/cleanup.ps1"

Write-Host "Downloading SmartConsole Cleanup script..." -ForegroundColor Cyan

try {
    $script = Invoke-RestMethod -Uri $url -UseBasicParsing
} catch {
    Write-Error "Failed to download script: $($_.Exception.Message)"
    exit 1
}

Write-Host "Running cleanup (NukeAll mode)..." -ForegroundColor Yellow

& ([scriptblock]::Create($script)) -NukeAll
