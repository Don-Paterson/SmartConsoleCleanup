# SmartConsoleCleanup

Removes legacy Check Point SmartConsole versions from Windows lab VMs, keeping only the current version (default: R82).

Designed for Skillable/lab environments where A-GUI VMs arrive pre-loaded with multiple SmartConsole versions consuming 8–9 GB per old version.

## Quick start (run as Administrator)

```powershell
irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/run-cleanup.ps1 | iex
```

This runs in **NukeAll mode** — no prompts, removes everything except R82.

## Manual / parameterised usage

```powershell
# Interactive (prompts before nuke mode)
.\cleanup.ps1

# Silent, no prompts
.\cleanup.ps1 -NukeAll

# Dry run — shows what would be removed, touches nothing
.\cleanup.ps1 -DryRun

# Dry run, silent
.\cleanup.ps1 -NukeAll -DryRun

# Protect a different version
.\cleanup.ps1 -NukeAll -ProtectedVersion "R81.20"
```

## What it does

For each SmartConsole version found (except the protected one):

1. Attempts the normal uninstaller with `/quiet /norestart`
2. **Verifies** the registry entry is actually gone (catches silent uninstall failures)
3. If the normal uninstall failed or had no uninstall string → **Nuke mode**:
   - Kills any processes whose path matches the install folder (won't touch R82)
   - Takes ownership and force-deletes the install folder
   - Removes registry entries from both 32-bit and 64-bit uninstall keys
   - Removes Start Menu program groups and shortcuts
4. After any successful uninstall, cleans up any leftover Start Menu entries

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `-NukeAll` | off | Suppress all Y/N prompts; auto-approve nuke mode |
| `-DryRun` | off | Log what would happen; make no changes |
| `-ProtectedVersion` | `R82` | Version string to skip (matched against DisplayName) |

## Log file

Each run writes a timestamped log to `%TEMP%\SmartConsole_Cleanup_<timestamp>.log`.

## Requirements

- PowerShell 5.1 or later
- Must run as Administrator
- Internet access to GitHub raw (for `irm | iex` delivery only)

## Compatibility

Tested against SmartConsole versions R77.30, R80.10, R80.20, R80.30, R80.40, R81.10, R81.20, R82 on Windows 10 (Skillable lab VMs).
