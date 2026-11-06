# WinToolBox

Command-line toolbox for Windows: versioned backup, disks and partitions, cleanup, repair,
networking, local accounts and security audit.

It only uses components that ship with Windows and requires no installation.

## Requirements

- Windows 10 or 11, with Windows PowerShell 5.1 (included in Windows)
- Administrator rights for disks, system images and scheduled tasks

## Getting started

Double-click `WintoolBox.bat`. Without administrator rights, the tool offers to restart with
those rights. Actions that require them are flagged in the menus.

## Menu

| Section | Option | Features |
|---|---|---|
| Data | 1. Backup and restore | Full and incremental backups, verification, restore, scheduled tasks, system image, restore point |
| Data | 2. Disks and partitions | Overview, health, scan, optimization, creation, resizing, drive letter, formatting, deletion |
| Maintenance | 3. Cleanup and repair | Cleanup after a scan, DISM, SFC |
| Administration | 4. System information | Hardware, processes, startup, failed services |
| Administration | 5. Network | Interfaces, connection test, listening ports, live connections, DNS cache |
| Administration | 6. Users and groups | Local accounts and group members |
| Protection | 7. Security and logs | Read-only audit, tool log |

## Backups

Each source has its own folder in the destination:

```text
<destination>\<name>-<hash>\
    20260115-200000123-full\   full version
        data\                  copied files
        files.tsv              source state, SHA-256 hashes
        dirs.txt               folders, including empty ones
        errors.txt             files and folders not backed up
        meta.json              version summary
    20260116-200000456-incr\   contains only the changed files
```

- **Restore:** every version can be restored directly, entirely or with a filter.
- **Integrity:** copies are checked using SHA-256 hashes, and so are restored files.
- **Interruption:** an unfinished version is never taken into account and its temporary folder is deleted on the next run.
- **Dependencies:** an incremental version needs the versions in its chain. Delete old versions using the menu, never by hand.
- **Open files:** the VSS option copies them, with administrator rights.
- **Links:** junctions and symbolic links are skipped and counted in the result.

### Scheduled tasks

A task runs with the limited rights of the current account, even when that account is not logged
on. This gives it access to the account's files and to local or external drives, but not to network
shares or open files (VSS). By default, it makes a full backup every 7 runs and keeps 4 chains.

Backups can also be started from the command line:

```bat
WintoolBox.bat -Task Backup -Source "D:\Documents" -Destination "E:\Backups" -Mode Incremental -FullEvery 7 -KeepChains 4
```

Exit codes: `0` success, `1` failure, `2` partial backup.

## Safe use

- Formatting and deleting require typing an exact phrase. They are refused on system and boot partitions.
- Cleanup first shows what it can delete and never touches Windows logs.
- The launcher uses `-ExecutionPolicy Bypass` for this process only, without changing the machine configuration.
- Logs (`logs\`) and reports (`reports\`) describe the machine. Do not publish them.

## Limitations

WinToolBox is not a full equivalent of AOMEI Backupper or EaseUS Todo Backup. It does not offer:

- sector-by-sector disk cloning;
- boot media for restoring a system that no longer starts;
- recovery of deleted partitions or files;
- MBR/GPT conversion or moving partitions;
- compression or encryption of file backups.

The system image relies on `wbadmin` and is restored from the Windows Recovery Environment.

## Tests

On Windows, in PowerShell:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester .\tests
```

## Structure

```text
WintoolBox.bat          launcher
src\WinToolBox.ps1      entry point and main menu
src\lib\Common.ps1      logging, display, input, file traversal
src\modules\*.ps1       one file per area
tests\                  Pester tests
```
