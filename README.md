<p align="center">
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@v2.16.0/icons/powershell/powershell-original.svg" alt="PowerShell" height="64">
  &nbsp;&nbsp;
  <img src="https://cdn.jsdelivr.net/gh/devicons/devicon@v2.16.0/icons/windows11/windows11-original.svg" alt="Windows" height="64">
</p>

<h1 align="center">WinToolBox</h1>

<p align="center"><strong>Windows backup, disk, process and security toolkit in PowerShell.</strong></p>

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
   [4] System information    hardware, startup, services
   [5] Processes             top CPU, memory, GPU, details, end, priority
   [6] Performance           live CPU, RAM, GPU, disks, network
   [7] Users and groups      local accounts and group members

  *** NETWORK AND SECURITY
   [8] Network               addresses, connection test, ports, DNS
   [9] Security and logs     read-only audit, tool log
```

## Quick start

1. Download or clone the repository.
2. Double-click `WintoolBox.bat`.
3. Accept the restart as administrator to unlock all features. The menu reopens in a new cmd window.

Requires Windows 10 or 11. Nothing to install.

## Backups

- Full and incremental versions, each restorable on its own.
- Every copy is checked with SHA-256, at backup and at restore.
- Open files are copied through VSS (administrator).

Delete old versions from the menu, never by hand: an incremental version needs its chain.

```bat
WintoolBox.bat -Task Backup -Source "D:\Documents" -Destination "E:\Backups" -Mode Incremental -FullEvery 7 -KeepChains 4
```

Exit codes: `0` success, `1` failure, `2` partial backup or source that lost most of its files.

Scheduled tasks run with the current account's limited rights: no VSS, no network shares.

## Safety

- Format and delete require typing an exact phrase. System, boot and recovery partitions are refused.
- Windows processes such as `lsass` cannot be ended or reprioritized.
- The execution policy changes for the running process only. A Group Policy or AppLocker block stops WinToolBox with a clear message.

`logs\` and `reports\` describe your machine: do not publish them.

## Limitations

- **Backups are not encrypted**: anyone holding the destination drive can read them, including EFS files, which are stored decrypted.
- **Keep an offline copy**: ransomware that reaches the destination can damage the backups.
- NTFS owners are not saved, and alternate data streams are not verified.
- A file deleted by accident leaves the backups once its chain expires.
- No cloning, boot media, file recovery, MBR/GPT conversion or temperature readings.
- `chkdsk` and names set by Windows stay in the Windows language.

## Tests

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester .\tests
```
