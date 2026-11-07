<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@v2.16.0/icons/powershell/powershell-original.svg" alt="PowerShell" height="64">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@v2.16.0/icons/windows11/windows11-original.svg" alt="Windows" height="64">
</p>

<h1 align="center">WinToolBox</h1>

<p align="center"><strong>Windows backup, disk management and security audit toolkit in PowerShell.<br>Nothing to install: everything it uses ships with Windows.</strong></p>

<p align="center">
  <a href="https://github.com/VISCHENZISCH/WinToolBox"><img src="https://img.shields.io/badge/GitHub-WinToolBox-181717?logo=github" alt="GitHub repository"></a>
  <a href="https://github.com/VISCHENZISCH/WinToolBox"><img src="https://img.shields.io/github/stars/VISCHENZISCH/WinToolBox?logo=github&label=Stars" alt="GitHub stars"></a>
  <a href="https://github.com/VISCHENZISCH/WinToolBox/commits/main"><img src="https://img.shields.io/github/last-commit/VISCHENZISCH/WinToolBox?logo=github&label=Last%20commit" alt="Last commit"></a>
  <br>
  <img src="https://img.shields.io/badge/PowerShell-5.1-2671BE?logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI%2BPHJlY3Qgd2lkdGg9IjI0IiBoZWlnaHQ9IjI0IiByeD0iNCIgZmlsbD0iIzI2NzFCRSIvPjxwYXRoIGZpbGw9Im5vbmUiIHN0cm9rZT0iI2ZmZiIgc3Ryb2tlLXdpZHRoPSIyLjYiIHN0cm9rZS1saW5lY2FwPSJyb3VuZCIgc3Ryb2tlLWxpbmVqb2luPSJyb3VuZCIgZD0iTTUgN2w1IDUtNSA1TTEyIDE4aDciLz48L3N2Zz4%3D" alt="PowerShell 5.1">
  <img src="https://img.shields.io/badge/Batch-launcher-4D4D4D?logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI%2BPHBhdGggZmlsbD0ibm9uZSIgc3Ryb2tlPSIjZmZmIiBzdHJva2Utd2lkdGg9IjIuNiIgc3Ryb2tlLWxpbmVjYXA9InJvdW5kIiBzdHJva2UtbGluZWpvaW49InJvdW5kIiBkPSJNNCA2bDYgNi02IDZNMTIgMTloOCIvPjwvc3ZnPg%3D%3D" alt="Batch launcher">
  <img src="https://img.shields.io/badge/Windows-10%20%7C%2011-0078D4?logo=data:image/svg%2Bxml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAxMjggMTI4Ij48cGF0aCBmaWxsPSIjMDA3OGQ0IiBkPSJNNjcuMzI4IDY3LjMzMWg2MC42NjlWMTI4SDY3LjMyOHptLTY3LjMyNSAwaDYwLjY2OVYxMjhILjAwM3pNNjcuMzI4IDBoNjAuNjY5djYwLjY2OUg2Ny4zMjh6TS4wMDMgMGg2MC42Njl2NjAuNjY5SC4wMDN6Ii8%2BPC9zdmc%2BCg%3D%3D" alt="Windows 10 and 11">
</p>

```text
  ************************************************************************
  WinToolBox 4.0
  ************************************************************************

  *** DATA PROTECTION
   [1] Backup and restore    versions, verification, schedules, system image

  *** STORAGE
   [2] Disks and partitions  health, scan, create, resize, format
   [3] Cleanup and repair    temporary files, DISM, SFC

  *** SYSTEM
   [4] System information    hardware, processes, startup, services
   [5] Users and groups      local accounts and group members

  *** NETWORK AND SECURITY
   [6] Network               addresses, connection test, ports, DNS
   [7] Security and logs     read-only audit, tool log
```

## Quick start

1. Download or clone the repository.
2. Double-click `WintoolBox.bat`.
3. Accept the restart as administrator to unlock disks, system images and scheduled tasks. Windows cannot elevate a running console, so the menu reopens in a new cmd window.

Requires Windows 10 or 11 with Windows PowerShell 5.1, which is included in Windows.

## Backups

Full and incremental versions, each one restorable on its own.

| Feature | Behavior |
|---|---|
| Copy check | SHA-256 of each copy compared with the source; a copy that differs is rejected |
| Restore | Backup files are checked first, so a damaged one never overwrites a target file |
| Interrupted backup | Ignored, and its temporary folder is removed on the next run |
| Retention | Empty or mostly failed full backups never push out a good chain |
| Open files | Copied through VSS (administrator) |
| NTFS permissions | Saved in `acls.txt`; reapplied at restore on request; owners are not saved |
| Links | Junctions and symbolic links are skipped and counted |

Delete old versions from the menu, never by hand: an incremental version needs its chain.

### Command line and scheduling

```bat
WintoolBox.bat -Task Backup -Source "D:\Documents" -Destination "E:\Backups" -Mode Incremental -FullEvery 7 -KeepChains 4
```

| Exit code | Meaning |
|---|---|
| `0` | Success |
| `1` | Failure |
| `2` | Partial backup, or the source suddenly lost most of its files |

Scheduled tasks run with the limited rights of the current account, default to a full backup
every 7 versions and keep 4 chains. They cannot reach network shares or use VSS. The main menu
warns when the last run failed.

## Safety

- **Format and delete:** show the volume's details and require typing an exact phrase.
- **Refused targets:** system, boot, recovery and hidden partitions, another Windows installation, and the drive that holds WinToolBox.
- **Volume repair:** asks for confirmation first. Offline repair refuses the same targets; for the Windows drive, chkdsk can check it at the next restart.
- **Disk with no partition table:** requires an exact phrase, because it may hold recoverable data.
- **Cleanup:** shows what it can delete first and never touches Windows logs.
- **Security audit:** read-only.
- **Execution policy:** the launcher runs `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass`, which applies to this process only; the machine configuration is not changed.

`logs\` and `reports\` describe your machine. Do not publish them.

## Limitations

- No sector-by-sector cloning, boot media, or recovery of deleted files and partitions.
- No MBR/GPT conversion or moving partitions.
- No compression or encryption of file backups.
- A file deleted by accident leaves the backups once its chain expires. A warning is shown only if the source loses most of its files at once.
- The system image relies on `wbadmin` and is restored from the Windows Recovery Environment.

## Project layout

```text
WintoolBox.bat       launcher
src\WinToolBox.ps1   entry point and main menu
src\lib\             logging, display, input, file traversal
src\modules\         Backup, Disk, Maintenance, Network, Security, System, Users
tests\               Pester tests
```

## Tests

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester .\tests
```
