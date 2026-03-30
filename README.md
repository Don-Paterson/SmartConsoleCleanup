# SmartConsoleCleanup

Removes legacy Check Point SmartConsole versions from Windows lab VMs, keeping only the current course version (default: R82).

Check Point lab VMs (A-GUI, A-HOST) ship with every SmartConsole version from R77.30 onwards pre-installed. Each version occupies 6–9 GB of disk space. This script removes all legacy versions cleanly and unattended in approximately 2 minutes.

## Quick start

Open any PowerShell session (does **not** need to be elevated — the script self-elevates):

```powershell
irm https://raw.githubusercontent.com/Don-Paterson/SmartConsoleCleanup/main/run-cleanup.ps1 | iex
```

A single UAC prompt will appear to approve the elevation. After that, the script runs fully unattended with no further interaction required.

## What it does

For each SmartConsole version found in the registry (except the protected version):

1. Kills any running processes belonging to that version's install folder
2. Uses `robocopy /MIR` to empty the install folder (handles deeply nested paths and locked files that `Remove-Item` cannot delete)
3. Force-deletes the now-empty install folder
4. Removes registry entries from both 32-bit and 64-bit uninstall keys
5. Removes Start Menu program groups and shortcuts

UAC consent prompts for child processes are suppressed for the duration of the script and restored on exit.

A timestamped log is written to `%TEMP%\SmartConsole_Cleanup_<timestamp>.log`.

## Manual usage

```powershell
# Dry run — shows exactly what would be removed, touches nothing
.\cleanup.ps1 -NukeAll -DryRun

# Silent, no prompts (same as the one-liner)
.\cleanup.ps1 -NukeAll

# Interactive — prompts before removing each version
.\cleanup.ps1

# Protect a different version (e.g. running an R81.20 course)
.\cleanup.ps1 -NukeAll -ProtectedVersion "R81.20"
```

## Parameters

| Parameter | Default | Description |
|---|---|---|
| `-NukeAll` | off | Suppress all Y/N prompts |
| `-NukeOnly` | off | Skip normal uninstallers; go straight to forced removal |
| `-DryRun` | off | Log what would happen; make no changes |
| `-ProtectedVersion` | `R82` | Version string to preserve (matched against DisplayName) |

## Tested against

| Version | Folders deleted | Registry cleaned | Start Menu cleaned |
|---|---|---|---|
| R77.30 | ✔ | ✔ | ✔ |
| R80.10 | ✔ | ✔ | ✔ |
| R80.20 | ✔ | ✔ | ✔ |
| R80.30 | ✔ | ✔ | ✔ |
| R80.40 | ✔ | ✔ | ✔ |
| R81.10 | ✔ | ✔ | ✔ |
| R81.20 | ✔ | ✔ | ✔ |
| R82 | protected | protected | protected |

Tested on Windows 10 (Skillable lab VMs, A-GUI and A-HOST roles). Runtime approximately 130 seconds for 7 versions.

## Requirements

- PowerShell 5.1 or later
- Internet access to GitHub raw content (for `irm | iex` delivery only)
- No pre-existing elevated session required — script self-elevates via UAC

## Related

- [SkillableMods](https://github.com/Don-Paterson/SkillableMods) — patches Skillable lab scripts for UK/GMT locale and non-interactive execution
