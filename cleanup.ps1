#Requires -RunAsAdministrator
# SmartConsole Cleanup Script
# Removes all Check Point SmartConsole versions except the protected version (default: R82)
# Compatible with PowerShell 5.1+
#
# Usage:
#   Interactive:   .\cleanup.ps1
#   Silent/CI:     .\cleanup.ps1 -NukeAll
#   Dry run:       .\cleanup.ps1 -DryRun
#   Silent dry:    .\cleanup.ps1 -NukeAll -DryRun
#   Keep version:  .\cleanup.ps1 -ProtectedVersion "R82"

[CmdletBinding()]
param(
    [switch]$NukeAll,
    [switch]$DryRun,
    [string]$ProtectedVersion = "R82"
)

$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$logFile   = "$env:TEMP\SmartConsole_Cleanup_$timestamp.log"

# ── Logging ──────────────────────────────────────────────────────────────────

function Log {
    param(
        [string]$Message,
        [string]$Level = "INFO"
    )
    $line = "$(Get-Date -Format 'u') [$Level] $Message"
    Add-Content -Path $logFile -Value $line -Encoding utf8
    Write-Host $line
}

# ── Helpers ───────────────────────────────────────────────────────────────────

function Get-SmartConsoleApps {
    $keys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    Get-ItemProperty $keys -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -like "Check Point SmartConsole*" }
}

function Get-InstallFolder {
    param([string]$AppName, [string]$RegistryLocation)

    # Use registry value if populated
    if ($RegistryLocation -and (Test-Path $RegistryLocation)) {
        return $RegistryLocation
    }

    # Fall back to known path pattern, deriving version from DisplayName
    # e.g. "Check Point SmartConsole R81.20" -> "R81.20"
    if ($AppName -match 'SmartConsole\s+(R[\d.]+)') {
        $ver = $Matches[1]
        $candidate = "C:\Program Files (x86)\CheckPoint\SmartConsole\$ver"
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    return $null
}

function Confirm-NukeMode {
    param([string]$AppName)
    if ($NukeAll) { return $true }
    $response = Read-Host "   Nuke mode for $AppName? (Y/N)"
    return $response -match '^[Yy]$'
}

function Test-AppStillInstalled {
    param([string]$AppName)
    $found = Get-SmartConsoleApps | Where-Object { $_.DisplayName -eq $AppName }
    return [bool]$found
}

# ── Start Menu cleanup ────────────────────────────────────────────────────────

function Remove-StartMenuEntries {
    param([string]$AppName)

    $startMenuRoots = @(
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs",
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"   # per-user fallback
    )

    foreach ($root in $startMenuRoots) {
        # Match folder names containing the app name or "Check Point SmartConsole <version>"
        Get-ChildItem -Path $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*$AppName*" -or $AppName -like "*$($_.Name)*" } |
            ForEach-Object {
                if ($DryRun) {
                    Log "   [DryRun] Would remove Start Menu folder: $($_.FullName)"
                } else {
                    try {
                        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop
                        Log "   ✔ Removed Start Menu folder: $($_.FullName)"
                    } catch {
                        Log "   ✖ Failed to remove Start Menu folder $($_.FullName): $($_.Exception.Message)" -Level WARN
                    }
                }
            }

        # Also catch any loose .lnk shortcuts at root level
        Get-ChildItem -Path $root -Filter "*.lnk" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like "*SmartConsole*" } |
            ForEach-Object {
                if ($DryRun) {
                    Log "   [DryRun] Would remove Start Menu shortcut: $($_.FullName)"
                } else {
                    try {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                        Log "   ✔ Removed Start Menu shortcut: $($_.FullName)"
                    } catch {
                        Log "   ✖ Failed to remove shortcut $($_.FullName): $($_.Exception.Message)" -Level WARN
                    }
                }
            }
    }
}

# ── Nuke mode ─────────────────────────────────────────────────────────────────

function Invoke-NukeMode {
    param(
        [string]$AppName,
        [string]$InstallLocation
    )

    Log "   ⚠ Nuke mode starting for: $AppName"

    # Kill only processes whose path matches this install folder (don't kill R82)
    if ($InstallLocation) {
        Get-Process -ErrorAction SilentlyContinue |
            Where-Object {
                try { $_.MainModule.FileName -like "$InstallLocation*" } catch { $false }
            } |
            ForEach-Object {
                if ($DryRun) {
                    Log "   [DryRun] Would kill process: $($_.Name) (PID $($_.Id))"
                } else {
                    Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue
                    Log "   ✔ Killed process: $($_.Name) (PID $($_.Id))"
                }
            }
    }

    # Remove install folder
    if ($InstallLocation -and (Test-Path $InstallLocation)) {
        if ($DryRun) {
            Log "   [DryRun] Would delete folder: $InstallLocation"
        } else {
            try {
                icacls $InstallLocation /grant "Administrators:F" /T /C | Out-Null
                Remove-Item -LiteralPath $InstallLocation -Recurse -Force -ErrorAction Stop
                Log "   ✔ Deleted folder: $InstallLocation"
            } catch {
                Log "   ✖ Failed to delete $InstallLocation : $($_.Exception.Message)" -Level WARN
            }
        }
    } else {
        Log "   ℹ No install folder found or already gone"
    }

    # Remove registry entries
    $regKeys = @(
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
    )
    foreach ($key in $regKeys) {
        Get-ChildItem $key -ErrorAction SilentlyContinue | ForEach-Object {
            $dn = (Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue).DisplayName
            if ($dn -eq $AppName) {
                if ($DryRun) {
                    Log "   [DryRun] Would remove registry key: $($_.PSPath)"
                } else {
                    try {
                        Remove-Item -Path $_.PSPath -Recurse -Force -ErrorAction Stop
                        Log "   ✔ Registry key removed"
                    } catch {
                        Log "   ✖ Failed to remove registry key: $($_.Exception.Message)" -Level WARN
                    }
                }
            }
        }
    }

    # Remove Start Menu entries
    Remove-StartMenuEntries -AppName $AppName

    Log "   ✔ Nuke mode complete for: $AppName"
}

# ── Main ──────────────────────────────────────────────────────────────────────

Log "===== SmartConsole Cleanup Started ====="
if ($DryRun)  { Log "*** DRY RUN MODE — no changes will be made ***" -Level WARN }
if ($NukeAll) { Log "*** NUKE ALL MODE — interactive prompts suppressed ***" }
Log "Protected version: $ProtectedVersion"
Log "Log file: $logFile"

$apps = Get-SmartConsoleApps

if (-not $apps) {
    Log "No SmartConsole installations found. Nothing to do."
    exit 0
}

Log "Found $(@($apps).Count) SmartConsole installation(s)"

foreach ($app in $apps) {
    $appName         = $app.DisplayName
    $uninstallString = $app.UninstallString
    $installLocation = Get-InstallFolder -AppName $appName -RegistryLocation $app.InstallLocation

    # ── Protected version guard ───────────────────────────────────────────────
    if ($appName -match [regex]::Escape($ProtectedVersion)) {
        Log ">>> Skipping $appName (protected)"
        continue
    }

    Log ">>> Processing: $appName"
    if ($installLocation) { Log "    Install folder: $installLocation" }
    else                   { Log "    Install folder: not found in registry or filesystem" -Level WARN }

    $uninstallSucceeded = $false

    # ── Attempt normal uninstall ──────────────────────────────────────────────
    if ($uninstallString) {
        Log "    Uninstall string: $uninstallString"
        if ($DryRun) {
            Log "    [DryRun] Would run uninstaller"
            $uninstallSucceeded = $true   # assume success in dry run
        } else {
            try {
                Start-Process -FilePath "cmd.exe" `
                    -ArgumentList "/c `"$uninstallString`" /quiet /norestart" `
                    -Wait -NoNewWindow -ErrorAction Stop
                Log "    ✔ Uninstaller exited"
            } catch {
                Log "    ✖ Uninstaller failed to launch: $($_.Exception.Message)" -Level WARN
            }

            # Verify: check if registry entry is actually gone
            if (Test-AppStillInstalled -AppName $appName) {
                Log "    ✖ App still present in registry after uninstall — uninstall likely failed" -Level WARN
            } else {
                $uninstallSucceeded = $true
                Log "    ✔ Verified: $appName removed from registry"
                # Clean up Start Menu even after a successful normal uninstall
                # (installers sometimes leave these behind)
                Remove-StartMenuEntries -AppName $appName
            }
        }
    } else {
        Log "    ✖ No uninstall string found" -Level WARN
    }

    # ── Fall through to nuke if needed ────────────────────────────────────────
    if (-not $uninstallSucceeded) {
        if (Confirm-NukeMode -AppName $appName) {
            Invoke-NukeMode -AppName $appName -InstallLocation $installLocation
        } else {
            Log "    Skipped nuke mode for $appName"
        }
    }
}

Log "===== SmartConsole Cleanup Completed ====="
Log "Log saved to: $logFile"
