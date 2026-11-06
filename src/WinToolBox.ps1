#requires -Version 5.1
<#
.SYNOPSIS
    WinToolBox: Windows backup, disk management, maintenance and administration.
.DESCRIPTION
    Without parameters, opens the interactive menu. With -Task Backup, runs a
    backup without a UI (used by scheduled tasks).
    -Task Backup exit codes: 0 success, 1 failure, 2 partial backup.
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
foreach ($module in 'Backup', 'Disk', 'Maintenance', 'System', 'Network', 'Users', 'Security') {
    . (Join-Path $PSScriptRoot "modules\$module.ps1")
}

Initialize-App -Root $script:AppRoot

if ($Task -eq 'Backup') {
    try {
        $result = New-Backup -Source $Source -Destination $Destination -Mode $Mode -FullEvery $FullEvery -KeepChains $KeepChains
        if ($result.Status -eq 'Partial') { exit 2 }
        exit 0
    }
    catch {
        Write-Log -Level ERROR -Message "Scheduled backup failed: $($_.Exception.Message)"
        exit 1
    }
}

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { Write-Verbose 'Console encoding left unchanged.' }
$Host.UI.RawUI.WindowTitle = "WinToolBox $script:AppVersion"

if (-not (Test-IsAdmin)) {
    Write-Status WARN 'Without administrator rights, disks and several tools will be unavailable.'
    if (Confirm-Action 'Restart as administrator?') {
        $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script:EntryScript`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
        exit 0
    }
}

$header = {
    $drive = [IO.DriveInfo]::new($env:SystemDrive)
    $role = if (Test-IsAdmin) { 'administrator' } else { 'standard' }
    Write-Host ('  {0}  |  rights: {1}  |  {2} {3} free of {4}' -f $env:COMPUTERNAME, $role, $env:SystemDrive,
        (Format-Bytes $drive.AvailableFreeSpace), (Format-Bytes $drive.TotalSize)) -ForegroundColor DarkGray
}

Show-Menu -Title "WinToolBox $script:AppVersion" -ExitLabel 'Quit' -Header $header -Items @(
    @{ Section = 'DATA'; Key = '1'; Label = 'Backup and restore'; Submenu = $true; Action = { Show-BackupMenu } }
    @{ Section = 'DATA'; Key = '2'; Label = 'Disks and partitions'; Submenu = $true; Action = { Show-DiskMenu } }
    @{ Section = 'MAINTENANCE'; Key = '3'; Label = 'Cleanup and repair'; Submenu = $true; Action = { Show-MaintenanceMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '4'; Label = 'System information'; Submenu = $true; Action = { Show-SystemMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '5'; Label = 'Network'; Submenu = $true; Action = { Show-NetworkMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '6'; Label = 'Users and groups'; Submenu = $true; Action = { Show-UsersMenu } }
    @{ Section = 'PROTECTION'; Key = '7'; Label = 'Security and logs'; Submenu = $true; Action = { Show-SecurityMenu } }
)
exit 0
