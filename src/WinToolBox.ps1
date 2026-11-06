#requires -Version 5.1
<#
.SYNOPSIS
    WinToolBox : sauvegarde, disques, maintenance et administration de Windows.
.DESCRIPTION
    Sans parametre, ouvre le menu interactif. Avec -Task Backup, execute une
    sauvegarde sans interface (utilise par les taches planifiees).
    Codes de sortie de -Task Backup : 0 succes, 1 echec, 2 sauvegarde partielle.
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
        Write-Log -Level ERROR -Message "Sauvegarde planifiee en echec : $($_.Exception.Message)"
        exit 1
    }
}

try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { Write-Verbose 'Encodage console inchange.' }
$Host.UI.RawUI.WindowTitle = "WinToolBox $script:AppVersion"

if (-not (Test-IsAdmin)) {
    Write-Status WARN 'Sans droits administrateur, les disques et plusieurs outils seront indisponibles.'
    if (Confirm-Action 'Relancer en administrateur ?') {
        $arguments = @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$script:EntryScript`"")
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $arguments
        exit 0
    }
}

$header = {
    $drive = [IO.DriveInfo]::new($env:SystemDrive)
    $role = if (Test-IsAdmin) { 'administrateur' } else { 'standard' }
    Write-Host ('  {0}  |  droits : {1}  |  {2} {3} libres sur {4}' -f $env:COMPUTERNAME, $role, $env:SystemDrive,
        (Format-Bytes $drive.AvailableFreeSpace), (Format-Bytes $drive.TotalSize)) -ForegroundColor DarkGray
}

Show-Menu -Title "WinToolBox $script:AppVersion" -ExitLabel 'Quitter' -Header $header -Items @(
    @{ Section = 'DONNEES'; Key = '1'; Label = 'Sauvegarde et restauration'; Submenu = $true; Action = { Show-BackupMenu } }
    @{ Section = 'DONNEES'; Key = '2'; Label = 'Disques et partitions'; Submenu = $true; Action = { Show-DiskMenu } }
    @{ Section = 'ENTRETIEN'; Key = '3'; Label = 'Nettoyage et reparation'; Submenu = $true; Action = { Show-MaintenanceMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '4'; Label = 'Informations systeme'; Submenu = $true; Action = { Show-SystemMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '5'; Label = 'Reseau'; Submenu = $true; Action = { Show-NetworkMenu } }
    @{ Section = 'ADMINISTRATION'; Key = '6'; Label = 'Utilisateurs et groupes'; Submenu = $true; Action = { Show-UsersMenu } }
    @{ Section = 'PROTECTION'; Key = '7'; Label = 'Securite et journaux'; Submenu = $true; Action = { Show-SecurityMenu } }
)
exit 0
