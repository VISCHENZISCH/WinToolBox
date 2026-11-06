# Informations systeme, en CIM : wmic a ete retire des versions recentes de Windows.

function Show-SystemInfo {
    $os = Get-CimInstance -ClassName Win32_OperatingSystem
    $computer = Get-CimInstance -ClassName Win32_ComputerSystem
    $bios = Get-CimInstance -ClassName Win32_BIOS
    $cpu = @(Get-CimInstance -ClassName Win32_Processor)
    $uptime = (Get-Date) - $os.LastBootUpTime

    $summary = [ordered]@{
        'Ordinateur' = $os.CSName
        'Systeme'    = '{0} ({1}, build {2})' -f $os.Caption, $os.OSArchitecture, $os.BuildNumber
        'Modele'     = '{0} {1}' -f $computer.Manufacturer, $computer.Model
        'BIOS'       = $bios.SMBIOSBIOSVersion
        'Processeur' = '{0} ({1} coeurs, {2} threads)' -f $cpu[0].Name.Trim(), ($cpu | Measure-Object -Property NumberOfCores -Sum).Sum, ($cpu | Measure-Object -Property NumberOfLogicalProcessors -Sum).Sum
        'Memoire'    = '{0} libres sur {1}' -f (Format-Bytes ($os.FreePhysicalMemory * 1KB)), (Format-Bytes $computer.TotalPhysicalMemory)
        'Demarrage'  = '{0:yyyy-MM-dd HH:mm} (depuis {1} j {2} h)' -f $os.LastBootUpTime, $uptime.Days, $uptime.Hours
    }
    foreach ($key in $summary.Keys) { Write-Host ('   {0,-14} {1}' -f $key, $summary[$key]) }

    Write-Host ''
    Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' | Select-Object DeviceID, VolumeName, FileSystem,
    @{ n = 'Libre'; e = { Format-Bytes $_.FreeSpace } },
    @{ n = 'Taille'; e = { Format-Bytes $_.Size } } | Format-Table -AutoSize | Out-Host
}

function Show-TopProcesses {
    Get-Process | Sort-Object WorkingSet64 -Descending | Select-Object -First 15 Name, Id,
    @{ n = 'Memoire'; e = { Format-Bytes $_.WorkingSet64 } },
    @{ n = 'CPU (s)'; e = { [math]::Round($_.CPU, 1) } } | Format-Table -AutoSize | Out-Host
}

function Show-StartupPrograms {
    Get-CimInstance -ClassName Win32_StartupCommand | Sort-Object Name | Select-Object Name, User, Location, Command | Format-Table -AutoSize -Wrap | Out-Host
}

function Show-FailedServices {
    $services = @(Get-CimInstance -ClassName Win32_Service -Filter "StartMode='Auto' AND State<>'Running' AND ExitCode<>0")
    if ($services.Count -eq 0) {
        Write-Status OK 'Aucun service automatique en echec.'
        return
    }
    $services | Select-Object Name, DisplayName, ExitCode | Format-Table -AutoSize | Out-Host
}

function Show-SystemMenu {
    Show-Menu -Title 'Informations systeme' -Items @(
        @{ Key = '1'; Label = 'Resume du systeme'; Action = { Show-SystemInfo } }
        @{ Key = '2'; Label = 'Processus les plus gourmands'; Action = { Show-TopProcesses } }
        @{ Key = '3'; Label = 'Programmes lances au demarrage'; Action = { Show-StartupPrograms } }
        @{ Key = '4'; Label = 'Services automatiques en echec'; Action = { Show-FailedServices } }
    )
}
