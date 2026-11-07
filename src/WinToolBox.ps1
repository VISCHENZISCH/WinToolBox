#requires -Version 5.1
<#
.SYNOPSIS
    WinToolBox: Windows backup, disk management, maintenance and administration.
.DESCRIPTION
    Without parameters, opens the interactive menu. With -Task Backup, runs a
    backup without a UI (used by scheduled tasks).
    -Task Backup exit codes: 0 success, 1 failure, 2 partial backup or source that
    suddenly lost most of its files.
#>
[CmdletBinding()]
param(
    [ValidateSet('Menu', 'Backup')][string]$Task = 'Menu',
    [string]$Source,
    [string]$Destination,
    [ValidateSet('Full', 'Incremental')][string]$Mode = 'Incremental',
    [int]$FullEvery = 0,
    [int]$KeepChains = 0
)

$ErrorActionPreference = 'Stop'
$script:AppVersion = '4.0'
$script:AppRoot = Split-Path -Parent $PSScriptRoot
$script:EntryScript = $PSCommandPath

. (Join-Path $PSScriptRoot 'lib\Common.ps1')
foreach ($module in 'Backup', 'Disk', 'Maintenance', 'System', 'Processes', 'Performance', 'Network', 'Users', 'Security') {
    . (Join-Path $PSScriptRoot "modules\$module.ps1")
}

Set-EnglishCulture
Initialize-App -Root $script:AppRoot

if ($Task -eq 'Backup') {
    try {
        $result = New-Backup -Source $Source -Destination $Destination -Mode $Mode -FullEvery $FullEvery -KeepChains $KeepChains
        if ($result.Status -eq 'Partial' -or $result.Shrunk) { exit 2 }
        exit 0
    }
    catch {
        Write-Log -Level ERROR -Message "Scheduled backup failed: $($_.Exception.Message)"
        exit 1
    }
}

$Host.UI.RawUI.WindowTitle = "WinToolBox $script:AppVersion"

if (-not (Test-IsAdmin)) {
    Write-Status WARN 'Without administrator rights, disks and several tools will be unavailable.'
    if (Confirm-Action 'Restart as administrator?') {
        # Windows cannot elevate a running console, so a new window is unavoidable. Starting cmd
        # keeps it a cmd window, with PowerShell inside it and no window of its own.
        $launcher = Join-Path $script:AppRoot 'WintoolBox.bat'
        Start-Process -FilePath $env:ComSpec -Verb RunAs -ArgumentList (New-ElevatedLauncherArguments -LauncherPath $launcher)
        exit 0
    }
}

$header = {
    $drive = [IO.DriveInfo]::new($env:SystemDrive)
    $role = if (Test-IsAdmin) { 'administrator' } else { 'standard' }
    Write-Host ('  {0}  |  rights: {1}  |  {2} {3} free of {4}' -f $env:COMPUTERNAME, $role, $env:SystemDrive,
        (Format-Bytes $drive.AvailableFreeSpace), (Format-Bytes $drive.TotalSize)) -ForegroundColor DarkGray
    foreach ($problem in $script:TaskProblems) { Write-Status WARN "Scheduled task '$($problem.Name)': $($problem.LastResult)." }
}

# Read once: scheduled tasks run unattended, so this is where their failures become visible.
$script:TaskProblems = @(Get-ScheduledBackupProblems)

# Set only for the menu and restored after it: the console belongs to the cmd window that started us,
# and cmd would otherwise keep showing accents wrongly once the tool has closed.
$originalEncoding = [Console]::OutputEncoding
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { Write-Verbose 'Console encoding left unchanged.' }
try {
    Show-Menu -Title "WinToolBox $script:AppVersion" -ExitLabel 'Quit' -Header $header -Items @(
        @{ Section = 'DATA PROTECTION'; Key = '1'; Label = 'Backup and restore'; Hint = 'versions, verification, schedules, system image'; Submenu = $true; Action = { Show-BackupMenu } }
        @{ Section = 'STORAGE'; Key = '2'; Label = 'Disks and partitions'; Hint = 'health, scan, create, resize, format'; Submenu = $true; Action = { Show-DiskMenu } }
        @{ Section = 'STORAGE'; Key = '3'; Label = 'Cleanup and repair'; Hint = 'temporary files, DISM, SFC'; Submenu = $true; Action = { Show-MaintenanceMenu } }
        @{ Section = 'SYSTEM'; Key = '4'; Label = 'System information'; Hint = 'hardware, startup, services'; Submenu = $true; Action = { Show-SystemMenu } }
        @{ Section = 'SYSTEM'; Key = '5'; Label = 'Processes'; Hint = 'top CPU, memory, GPU, details, end, priority'; Submenu = $true; Action = { Show-ProcessMenu } }
        @{ Section = 'SYSTEM'; Key = '6'; Label = 'Performance'; Hint = 'live CPU, RAM, GPU, disks, network'; Submenu = $true; Action = { Show-PerformanceMenu } }
        @{ Section = 'SYSTEM'; Key = '7'; Label = 'Users and groups'; Hint = 'local accounts and group members'; Submenu = $true; Action = { Show-UsersMenu } }
        @{ Section = 'NETWORK AND SECURITY'; Key = '8'; Label = 'Network'; Hint = 'addresses, connection test, ports, DNS'; Submenu = $true; Action = { Show-NetworkMenu } }
        @{ Section = 'NETWORK AND SECURITY'; Key = '9'; Label = 'Security and logs'; Hint = 'read-only audit, tool log'; Submenu = $true; Action = { Show-SecurityMenu } }
    )
}
finally {
    try { [Console]::OutputEncoding = $originalEncoding } catch { Write-Verbose 'Console encoding left unchanged.' }
}
exit 0
